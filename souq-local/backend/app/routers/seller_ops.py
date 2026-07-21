from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, require_admin, require_seller
from app.database import get_db
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
    buyer_id: UUID
    seller_id: UUID
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
    result = await session.execute(
        select(Notification).where(Notification.user_id == user.id, Notification.read_at.is_(None))
    )
    now = datetime.now(UTC)
    for item in result.scalars().all():
        item.read_at = now
    await session.commit()


@router.get("/messages/conversations", response_model=list[ConversationOut])
async def list_conversations(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[ConversationOut]:
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()

    if seller:
        result = await session.execute(
            select(Conversation).where(Conversation.seller_id == seller.id).order_by(Conversation.last_message_at.desc())
        )
        conversations = list(result.scalars().all())
        outs: list[ConversationOut] = []
        for conversation in conversations:
            buyer = await session.get(User, conversation.buyer_id)
            unread = await session.scalar(
                select(func.count(Message.id)).where(
                    Message.conversation_id == conversation.id,
                    Message.sender_id != user.id,
                    Message.read_at.is_(None),
                )
            )
            last = await session.scalar(
                select(Message.body)
                .where(Message.conversation_id == conversation.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            outs.append(
                ConversationOut(
                    id=conversation.id,
                    buyer_id=conversation.buyer_id,
                    seller_id=conversation.seller_id,
                    last_message_at=conversation.last_message_at,
                    peer_name=(buyer.display_name or buyer.email) if buyer else "Buyer",
                    unread_count=int(unread or 0),
                    last_message_preview=(last or "")[:160],
                )
            )
        return outs

    result = await session.execute(
        select(Conversation).where(Conversation.buyer_id == user.id).order_by(Conversation.last_message_at.desc())
    )
    conversations = list(result.scalars().all())
    outs = []
    for conversation in conversations:
        seller_profile = await session.get(SellerProfile, conversation.seller_id)
        unread = await session.scalar(
            select(func.count(Message.id)).where(
                Message.conversation_id == conversation.id,
                Message.sender_id != user.id,
                Message.read_at.is_(None),
            )
        )
        last = await session.scalar(
            select(Message.body)
            .where(Message.conversation_id == conversation.id)
            .order_by(Message.created_at.desc())
            .limit(1)
        )
        outs.append(
            ConversationOut(
                id=conversation.id,
                buyer_id=conversation.buyer_id,
                seller_id=conversation.seller_id,
                last_message_at=conversation.last_message_at,
                peer_name=seller_profile.business_name if seller_profile else "Seller",
                unread_count=int(unread or 0),
                last_message_preview=(last or "")[:160],
            )
        )
    return outs


@router.post("/messages/sellers/{seller_id}", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def start_or_send_to_seller(
    seller_id: UUID,
    payload: MessageCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Message:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not found")
    if seller.user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot message your own store")

    existing = await session.execute(
        select(Conversation).where(Conversation.buyer_id == user.id, Conversation.seller_id == seller_id)
    )
    conversation = existing.scalar_one_or_none()
    is_new = conversation is None
    if conversation is None:
        conversation = Conversation(id=uuid4(), buyer_id=user.id, seller_id=seller_id)
        session.add(conversation)
        await session.flush()

    message = Message(
        id=uuid4(),
        conversation_id=conversation.id,
        sender_id=user.id,
        body=payload.body.strip(),
    )
    conversation.last_message_at = datetime.now(UTC)
    session.add(message)
    if is_new:
        seller.inquiry_count = int(seller.inquiry_count or 0) + 1
    await notify_user(
        session,
        user_id=seller.user_id,
        title="New inquiry",
        body=payload.body.strip()[:120],
        kind="message",
        data={"conversation_id": str(conversation.id)},
    )
    await session.commit()
    await session.refresh(message)
    return message


@router.get("/messages/conversations/{conversation_id}", response_model=list[MessageOut])
async def list_messages(
    conversation_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[Message]:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    seller = await session.get(SellerProfile, conversation.seller_id)
    if conversation.buyer_id != user.id and (seller is None or seller.user_id != user.id):
        raise HTTPException(status_code=404, detail="Conversation not found")

    result = await session.execute(
        select(Message).where(Message.conversation_id == conversation_id).order_by(Message.created_at.asc())
    )
    messages = list(result.scalars().all())
    now = datetime.now(UTC)
    for message in messages:
        if message.sender_id != user.id and message.read_at is None:
            message.read_at = now
    await session.commit()
    return messages


@router.post("/messages/conversations/{conversation_id}", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def reply_message(
    conversation_id: UUID,
    payload: MessageCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Message:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    seller = await session.get(SellerProfile, conversation.seller_id)
    if conversation.buyer_id != user.id and (seller is None or seller.user_id != user.id):
        raise HTTPException(status_code=404, detail="Conversation not found")

    message = Message(
        id=uuid4(),
        conversation_id=conversation.id,
        sender_id=user.id,
        body=payload.body.strip(),
    )
    conversation.last_message_at = datetime.now(UTC)
    session.add(message)
    recipient = seller.user_id if conversation.buyer_id == user.id and seller else conversation.buyer_id
    await notify_user(
        session,
        user_id=recipient,
        title="New message",
        body=payload.body.strip()[:120],
        kind="message",
        data={"conversation_id": str(conversation.id)},
    )
    await session.commit()
    await session.refresh(message)
    return message


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
    """
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
    user: User = Depends(require_admin),
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
async def admin_set_status(
    user_id: UUID,
    status_value: UserStatus = Query(alias="status"),
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    target.status = status_value
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


@router.post("/admin/sellers/{seller_id}/verify", status_code=status.HTTP_204_NO_CONTENT)
async def admin_verify_seller(
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


@router.get("/admin/sellers/pending", response_model=list[dict])
async def admin_pending_sellers(
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> list[dict]:
    result = await session.execute(
        select(SellerProfile).where(SellerProfile.verification_status == VerificationStatus.PENDING)
    )
    return [
        {
            "id": str(s.id),
            "business_name": s.business_name,
            "city": s.city,
            "phone": s.phone,
            "user_id": str(s.user_id),
        }
        for s in result.scalars().all()
    ]
