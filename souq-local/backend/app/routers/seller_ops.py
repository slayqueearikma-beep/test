from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import (
    get_current_user,
    require_admin,
    require_seller,
    require_staff,
    require_verified_email,
)
from app.database import get_db
from app.limiter import limiter
from app.models import (
    AdminAuditLog,
    Conversation,
    Message,
    Notification,
    Product,
    SellerProfile,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
    UserRole,
    UserStatus,
    VerificationStatus,
)
from app.services.notifications import notify_user
from app.services.security import revoke_all_refresh_tokens

router = APIRouter(tags=["seller-ops"])


class AnalyticsOut(BaseModel):
    product_count: int
    available_product_count: int
    service_count: int = 0
    profile_view_count: int
    inquiry_count: int
    favorite_count: int
    contact_click_count: int
    avg_response_minutes: int
    review_count: int
    average_rating: float
    verification_status: VerificationStatus
    is_premium: bool
    follower_estimate: int = 0


class NotificationOut(BaseModel):
    id: UUID
    title: str
    body: str
    kind: str
    data: dict
    read_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=4000)

    @field_validator("body")
    @classmethod
    def strip_nonempty(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Message body cannot be empty")
        return cleaned


class MessageOut(BaseModel):
    id: UUID
    conversation_id: UUID
    sender_id: UUID
    body: str
    read_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class ConversationOut(BaseModel):
    id: UUID
    # Legacy aliases kept for older clients: buyer_id ≈ peer when viewing as store owner historically.
    buyer_id: UUID
    seller_id: UUID | None = None
    peer_user_id: UUID
    last_message_at: datetime
    peer_name: str = ""
    unread_count: int = 0
    last_message_preview: str = ""


class PlanOut(BaseModel):
    id: UUID
    code: str
    name: str
    description: str
    price_mad: float
    billing_period_days: int
    features: list
    is_active: bool

    model_config = {"from_attributes": True}


class SubscriptionOut(BaseModel):
    id: UUID
    plan: PlanOut
    status: SubscriptionStatus
    current_period_start: datetime
    current_period_end: datetime
    provider: str


class AdminUserOut(BaseModel):
    id: UUID
    email: str
    display_name: str
    account_type: str
    role: UserRole
    status: UserStatus
    is_premium: bool
    created_at: datetime


async def _seller_profile(user: User, session: AsyncSession) -> SellerProfile:
    result = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    seller = result.scalar_one_or_none()
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller profile not found")
    return seller


@router.get("/seller/analytics", response_model=AnalyticsOut)
async def seller_analytics(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> AnalyticsOut:
    from app.models import SellerFollow, Service

    seller = await _seller_profile(user, session)
    product_count = await session.scalar(select(func.count(Product.id)).where(Product.seller_id == seller.id))
    available = await session.scalar(
        select(func.count(Product.id)).where(Product.seller_id == seller.id, Product.is_available.is_(True))
    )
    service_count = await session.scalar(select(func.count(Service.id)).where(Service.seller_id == seller.id))
    followers = await session.scalar(
        select(func.count(SellerFollow.id)).where(SellerFollow.seller_id == seller.id)
    )
    return AnalyticsOut(
        product_count=int(product_count or 0),
        available_product_count=int(available or 0),
        service_count=int(service_count or 0),
        profile_view_count=seller.profile_view_count,
        inquiry_count=int(seller.inquiry_count or 0),
        favorite_count=int(seller.favorite_count or 0),
        contact_click_count=int(seller.contact_click_count or 0),
        avg_response_minutes=int(seller.avg_response_minutes or 0),
        review_count=seller.review_count,
        average_rating=seller.average_rating,
        verification_status=seller.verification_status,
        is_premium=seller.is_premium or user.is_premium,
        follower_estimate=int(followers or 0),
    )


@router.post("/seller/verification/request", status_code=status.HTTP_204_NO_CONTENT)
async def request_verification(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> None:
    seller = await _seller_profile(user, session)
    if seller.verification_status == VerificationStatus.VERIFIED:
        return
    seller.verification_status = VerificationStatus.PENDING
    await session.commit()


@router.get("/notifications", response_model=list[NotificationOut])
async def list_notifications(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[Notification]:
    result = await session.execute(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


@router.post("/notifications/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_notification_read(
    notification_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    item = await session.get(Notification, notification_id)
    if item is None or item.user_id != user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    item.read_at = datetime.now(UTC)
    await session.commit()


@router.post("/notifications/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_notifications_read(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await session.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
        .values(read_at=datetime.now(UTC))
    )
    await session.commit()


@router.get("/messages/conversations", response_model=list[ConversationOut])
async def list_conversations(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[ConversationOut]:
    from app.services.messaging import conversation_participant_filter, peer_display_names

    result = await session.execute(
        select(Conversation)
        .where(conversation_participant_filter(user.id))
        .order_by(Conversation.last_message_at.desc())
        .limit(limit)
        .offset(offset)
    )
    conversations = list(result.scalars().all())
    return await _conversation_outs(session, conversations, user_id=user.id)


async def _conversation_outs(
    session: AsyncSession,
    conversations: list[Conversation],
    *,
    user_id: UUID,
) -> list[ConversationOut]:
    from app.services.messaging import peer_display_names

    if not conversations:
        return []

    conversation_ids = [c.id for c in conversations]
    peer_ids = {c.other_participant(user_id) for c in conversations}

    unread_rows = await session.execute(
        select(Message.conversation_id, func.count(Message.id))
        .where(
            Message.conversation_id.in_(conversation_ids),
            Message.sender_id != user_id,
            Message.read_at.is_(None),
        )
        .group_by(Message.conversation_id)
    )
    unread_map = {row[0]: int(row[1]) for row in unread_rows.all()}

    last_rows = await session.execute(
        select(Message.conversation_id, Message.body)
        .where(Message.conversation_id.in_(conversation_ids))
        .distinct(Message.conversation_id)
        .order_by(Message.conversation_id, Message.created_at.desc())
    )
    last_map = {row[0]: (row[1] or "")[:160] for row in last_rows.all()}
    peer_map = await peer_display_names(session, peer_ids)

    outs: list[ConversationOut] = []
    for c in conversations:
        peer_id = c.other_participant(user_id)
        outs.append(
            ConversationOut(
                id=c.id,
                buyer_id=peer_id,
                seller_id=c.context_seller_id,
                peer_user_id=peer_id,
                last_message_at=c.last_message_at,
                peer_name=peer_map.get(peer_id, "User"),
                unread_count=unread_map.get(c.id, 0),
                last_message_preview=last_map.get(c.id, ""),
            )
        )
    return outs


@router.post("/messages/users/{user_id}", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def start_or_send_to_user(
    request: Request,
    user_id: UUID,
    payload: MessageCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> Message:
    """Start or continue a peer conversation with any authenticated user."""
    from app.services.messaging import get_or_create_conversation, send_message

    peer_profile = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user_id))
    ).scalar_one_or_none()
    context_seller_id = peer_profile.id if peer_profile is not None and peer_profile.is_active else None

    conversation, is_new = await get_or_create_conversation(
        session,
        initiator_id=user.id,
        peer_user_id=user_id,
        context_seller_id=context_seller_id,
    )
    return await send_message(
        session,
        conversation=conversation,
        sender=user,
        body=payload.body,
        is_new=is_new,
        notify_title="New inquiry" if context_seller_id else "New message",
    )


@router.post("/messages/sellers/{seller_id}", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def start_or_send_to_seller(
    request: Request,
    seller_id: UUID,
    payload: MessageCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> Message:
    """Message a storefront. Works for buyers and sellers (including seller↔seller)."""
    from app.services.messaging import get_or_create_conversation, send_message

    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not found")
    if seller.user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot message your own store")

    conversation, is_new = await get_or_create_conversation(
        session,
        initiator_id=user.id,
        peer_user_id=seller.user_id,
        context_seller_id=seller.id,
    )
    return await send_message(
        session,
        conversation=conversation,
        sender=user,
        body=payload.body,
        is_new=is_new,
        notify_title="New inquiry",
    )


@router.post("/messages/sellers/{seller_id}/open", response_model=ConversationOut, status_code=status.HTTP_200_OK)
@limiter.limit("30/minute")
async def open_seller_conversation(
    request: Request,
    seller_id: UUID,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> ConversationOut:
    """Open (or resume) a storefront thread without sending a canned first message."""
    from app.services.messaging import get_or_create_conversation

    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not found")
    if seller.user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot message your own store")

    conversation, _ = await get_or_create_conversation(
        session,
        initiator_id=user.id,
        peer_user_id=seller.user_id,
        context_seller_id=seller.id,
    )
    await session.commit()
    await session.refresh(conversation)

    return ConversationOut(
        id=conversation.id,
        buyer_id=seller.user_id,
        seller_id=seller.id,
        peer_user_id=seller.user_id,
        last_message_at=conversation.last_message_at,
        peer_name=seller.business_name,
        unread_count=0,
        last_message_preview="",
    )


@router.get("/messages/conversations/{conversation_id}", response_model=list[MessageOut])
async def list_messages(
    conversation_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[Message]:
    from app.services.messaging import require_conversation_participant

    await require_conversation_participant(session, conversation_id, user.id)

    result = await session.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    messages = list(result.scalars().all())
    unread_ids = [m.id for m in messages if m.sender_id != user.id and m.read_at is None]
    if unread_ids:
        await session.execute(
            update(Message)
            .where(Message.id.in_(unread_ids))
            .values(read_at=datetime.now(UTC))
        )
        await session.commit()
        for message in messages:
            if message.id in set(unread_ids):
                message.read_at = datetime.now(UTC)
    messages.reverse()
    return messages


@router.post("/messages/conversations/{conversation_id}", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("60/minute")
async def reply_message(
    request: Request,
    conversation_id: UUID,
    payload: MessageCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Message:
    from app.services.messaging import require_conversation_participant, send_message

    conversation = await require_conversation_participant(session, conversation_id, user.id)
    return await send_message(
        session,
        conversation=conversation,
        sender=user,
        body=payload.body,
        is_new=False,
        notify_title="New message",
    )


@router.get("/subscriptions/plans", response_model=list[PlanOut])
async def list_plans(session: AsyncSession = Depends(get_db)) -> list[SubscriptionPlan]:
    result = await session.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.is_active.is_(True)).order_by(SubscriptionPlan.price_mad.asc())
    )
    return list(result.scalars().all())


@router.get("/subscriptions/me", response_model=SubscriptionOut | None)
async def my_subscription(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut | None:
    result = await session.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.ACTIVE)
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    sub = result.scalar_one_or_none()
    if sub is None:
        return None
    return SubscriptionOut(
        id=sub.id,
        plan=PlanOut.model_validate(sub.plan),
        status=sub.status,
        current_period_start=sub.current_period_start,
        current_period_end=sub.current_period_end,
        provider=sub.provider,
    )


@router.post("/subscriptions/subscribe/{plan_code}", response_model=SubscriptionOut, status_code=status.HTTP_201_CREATED)
async def subscribe(
    plan_code: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Activate premium membership for platform visibility (not buyer↔seller payments).

    Membership billing can later plug into an external provider via provider/provider_reference.
    This endpoint never processes marketplace transaction payments.

    In production, free self-activation is disabled — a payment provider webhook or admin
    grant must set the subscription. Development keeps manual activation for local testing.
    """
    from app.config import settings

    if settings.app_env in {"production", "prod"}:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Self-serve premium activation is disabled until a billing provider is configured. "
                "Contact support or use an admin grant."
            ),
        )

    result = await session.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.code == plan_code, SubscriptionPlan.is_active.is_(True))
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")

    existing = await session.execute(
        select(Subscription).where(Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.ACTIVE)
    )
    for sub in existing.scalars().all():
        sub.status = SubscriptionStatus.CANCELED

    now = datetime.now(UTC)
    subscription = Subscription(
        id=uuid4(),
        user_id=user.id,
        plan_id=plan.id,
        status=SubscriptionStatus.ACTIVE,
        current_period_start=now,
        current_period_end=now + timedelta(days=plan.billing_period_days),
        provider="manual",
        provider_reference=f"manual-{uuid4().hex[:12]}",
    )
    session.add(subscription)
    user.is_premium = True
    user.premium_until = subscription.current_period_end

    if user.account_type.value == "seller" or plan.code.startswith("seller"):
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
        ).scalar_one_or_none()
        if seller:
            seller.is_premium = True

    await notify_user(
        session,
        user_id=user.id,
        title="Premium activated",
        body=f"{plan.name} is now active — enjoy higher visibility",
        kind="premium",
        data={"plan_code": plan.code},
    )
    await session.commit()
    await session.refresh(subscription)
    subscription.plan = plan
    return SubscriptionOut(
        id=subscription.id,
        plan=PlanOut.model_validate(plan),
        status=subscription.status,
        current_period_start=subscription.current_period_start,
        current_period_end=subscription.current_period_end,
        provider=subscription.provider,
    )


@router.get("/admin/users", response_model=list[AdminUserOut])
async def admin_list_users(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[AdminUserOut]:
    result = await session.execute(select(User).order_by(User.created_at.desc()).limit(limit))
    users = list(result.scalars().all())
    return [
        AdminUserOut(
            id=u.id,
            email=u.email,
            display_name=u.display_name,
            account_type=u.account_type.value,
            role=u.role,
            status=u.status,
            is_premium=u.is_premium,
            created_at=u.created_at,
        )
        for u in users
    ]


@router.patch("/admin/users/{user_id}/status", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def admin_set_status(
    request: Request,
    user_id: UUID,
    status_value: UserStatus = Query(alias="status"),
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    target.status = status_value
    if status_value in {UserStatus.SUSPENDED, UserStatus.DELETED}:
        await revoke_all_refresh_tokens(session, target.id)
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=user.id,
            action="set_user_status",
            target_type="user",
            target_id=str(user_id),
            metadata_={"status": status_value.value},
        )
    )
    await session.commit()


class AdminPremiumGrant(BaseModel):
    plan_code: str = Field(min_length=2, max_length=64)
    days: int = Field(default=30, ge=1, le=366)


@router.post("/admin/users/{user_id}/premium", response_model=SubscriptionOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def admin_grant_premium(
    request: Request,
    user_id: UUID,
    payload: AdminPremiumGrant,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Admin-only premium visibility grant (no in-app payment)."""
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    plan = (
        await session.execute(
            select(SubscriptionPlan).where(
                SubscriptionPlan.code == payload.plan_code,
                SubscriptionPlan.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")

    existing = await session.execute(
        select(Subscription).where(
            Subscription.user_id == target.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
    )
    for sub in existing.scalars().all():
        sub.status = SubscriptionStatus.CANCELED

    now = datetime.now(UTC)
    subscription = Subscription(
        id=uuid4(),
        user_id=target.id,
        plan_id=plan.id,
        status=SubscriptionStatus.ACTIVE,
        current_period_start=now,
        current_period_end=now + timedelta(days=payload.days),
        provider="admin_grant",
        provider_reference=f"admin-{admin.id.hex[:8]}-{uuid4().hex[:8]}",
    )
    session.add(subscription)
    target.is_premium = True
    target.premium_until = subscription.current_period_end
    if target.account_type.value == "seller" or plan.code.startswith("seller"):
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == target.id))
        ).scalar_one_or_none()
        if seller:
            seller.is_premium = True

    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="grant_premium",
            target_type="user",
            target_id=str(user_id),
            metadata_={"plan_code": plan.code, "days": payload.days},
        )
    )
    await notify_user(
        session,
        user_id=target.id,
        title="Premium activated",
        body=f"{plan.name} granted by MarGem staff",
        kind="premium",
        data={"plan_code": plan.code},
    )
    await session.commit()
    await session.refresh(subscription)
    result = await session.execute(
        select(Subscription).options(selectinload(Subscription.plan)).where(Subscription.id == subscription.id)
    )
    subscription = result.scalar_one()
    return SubscriptionOut(
        id=subscription.id,
        plan=PlanOut.model_validate(subscription.plan),
        status=subscription.status,
        current_period_start=subscription.current_period_start,
        current_period_end=subscription.current_period_end,
        provider=subscription.provider,
    )


@router.post("/admin/sellers/{seller_id}/verify", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("30/minute")
async def admin_verify_seller(
    request: Request,
    seller_id: UUID,
    approve: bool = True,
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller not found")
    seller.verification_status = VerificationStatus.VERIFIED if approve else VerificationStatus.REJECTED
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=user.id,
            action="verify_seller" if approve else "reject_seller",
            target_type="seller",
            target_id=str(seller_id),
            metadata_={},
        )
    )
    await notify_user(
        session,
        user_id=seller.user_id,
        title="Verification update",
        body="Your business was verified" if approve else "Verification was rejected",
        kind="verification",
        data={"seller_id": str(seller_id)},
    )
    await session.commit()


class PendingSellerOut(BaseModel):
    id: UUID
    business_name: str
    city: str
    phone: str
    user_id: UUID

    model_config = {"from_attributes": True}


@router.get("/admin/sellers/pending", response_model=list[PendingSellerOut])
async def admin_pending_sellers(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[PendingSellerOut]:
    result = await session.execute(
        select(SellerProfile)
        .where(SellerProfile.verification_status == VerificationStatus.PENDING)
        .order_by(SellerProfile.created_at.asc())
        .limit(limit)
        .offset(offset)
    )
    return [
        PendingSellerOut(
            id=s.id,
            business_name=s.business_name,
            city=s.city,
            phone=s.phone,
            user_id=s.user_id,
        )
        for s in result.scalars().all()
    ]
