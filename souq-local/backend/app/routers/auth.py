import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, new_local_firebase_uid
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AccountType, AuthToken, RefreshToken, SellerProfile, User, UserRole, UserStatus
from app.schemas import (
    ChangePasswordRequest,
    DeleteAccountRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    TokenResponse,
    UserOut,
    UserRegister,
    UserRegisterFirebase,
)
from app.services.audit import log_security_event
from app.services.email import email_service
from app.services.password_policy import validate_password_strength
from app.services.security import (
    create_access_token,
    hash_password,
    issue_refresh_token,
    revoke_all_refresh_tokens,
    revoke_refresh_token,
    rotate_refresh_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _auth_action_body(*, path: str, token: str, intro: str) -> str:
    """Include HTTPS web + custom-scheme deep links so mobile opens the app with the token."""
    base = settings.public_app_url.rstrip("/")
    web = f"{base}{path}?token={token}"
    deep = f"margem://app{path}?token={token}"
    return (
        f"{intro}\n\n"
        f"Open in the MarGem app:\n{deep}\n\n"
        f"Or use this link:\n{web}\n\n"
        f"Code: {token}"
    )


class EmailRequest(BaseModel):
    email: EmailStr


class TokenConfirmRequest(BaseModel):
    token: str = Field(min_length=20, max_length=256)


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=20, max_length=256)
    new_password: str = Field(min_length=8, max_length=128)


class SessionOut(BaseModel):
    id: UUID
    device_name: str
    ip_address: str
    user_agent: str
    created_at: datetime
    last_seen_at: datetime | None
    current: bool = False


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def _issue_auth_token(session: AsyncSession, user_id: UUID, purpose: str, hours: int = 24) -> str:
    plain = secrets.token_urlsafe(32)
    session.add(
        AuthToken(
            id=uuid4(),
            user_id=user_id,
            purpose=purpose,
            token_hash=_hash_token(plain),
            expires_at=datetime.now(UTC) + timedelta(hours=hours),
        )
    )
    await session.flush()
    return plain


async def _token_response(session: AsyncSession, user: User, request: Request | None = None) -> TokenResponse:
    device = ""
    ip = ""
    ua = ""
    if request is not None:
        ip = request.client.host if request.client else ""
        ua = (request.headers.get("user-agent") or "")[:255]
        device = (request.headers.get("x-device-name") or ua[:80] or "Device")[:120]

    refresh_token = await issue_refresh_token(session, user.id)
    # Attach device metadata to newest refresh token
    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked.is_(False))
        .order_by(RefreshToken.created_at.desc())
        .limit(1)
    )
    stored = result.scalar_one_or_none()
    if stored is not None:
        stored.device_name = device
        stored.ip_address = ip
        stored.user_agent = ua
        stored.last_seen_at = datetime.now(UTC)

    user.last_login_at = datetime.now(UTC)
    await session.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(user),
    )


def _role_for_account(account_type: AccountType) -> UserRole:
    return UserRole.SELLER if account_type == AccountType.SELLER else UserRole.BUYER


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register(
    request: Request,
    payload: UserRegister,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    email = payload.email.lower()
    existing = await session.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        log_security_event("register_conflict", email=email)
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    account_type = AccountType(payload.account_type.value)
    user = User(
        firebase_uid=new_local_firebase_uid(),
        email=email,
        password_hash=hash_password(payload.password),
        account_type=account_type,
        display_name=payload.display_name.strip(),
        role=_role_for_account(account_type),
        status=UserStatus.ACTIVE,
    )
    session.add(user)
    await session.flush()

    verify_token = await _issue_auth_token(session, user.id, "email_verify", hours=48)
    delivery = email_service.send(
        to=user.email,
        subject="Verify your MarGem email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=verify_token,
            intro="Welcome to MarGem. Verify your email to secure your account.",
        ),
    )
    log_security_event("register_success", user_id=str(user.id), account_type=user.account_type.value)

    response = await _token_response(session, user, request)
    # TokenResponse schema is fixed; verification tokens are delivered by email / logs only.
    _ = delivery
    return response


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.auth_rate_limit)
async def login(
    request: Request,
    payload: LoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        log_security_event(
            "login_failed",
            email=payload.email.lower(),
            client=request.client.host if request.client else "unknown",
        )
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    log_security_event("login_success", user_id=str(user.id))
    return await _token_response(session, user, request)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit(settings.auth_rate_limit)
async def refresh_tokens(
    request: Request,
    payload: RefreshRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    rotated = await rotate_refresh_token(session, payload.refresh_token)
    if rotated is None:
        log_security_event("refresh_failed", client=request.client.host if request.client else "unknown")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user_id, new_refresh = rotated
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if user.status == UserStatus.SUSPENDED:
        await revoke_all_refresh_tokens(session, user.id)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        await revoke_all_refresh_tokens(session, user.id)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account deleted")

    await session.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=new_refresh,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(user),
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def logout(
    request: Request,
    payload: LogoutRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    await revoke_refresh_token(session, payload.refresh_token)
    await session.commit()
    log_security_event("logout", client=request.client.host if request.client else "unknown")


@router.post("/register-firebase", response_model=UserOut, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register_firebase(
    request: Request,
    payload: UserRegisterFirebase,
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    if settings.app_env in {"production", "prod"} or not settings.debug:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not available")

    existing = await session.execute(
        select(User).where((User.firebase_uid == payload.firebase_uid) | (User.email == payload.email.lower()))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

    account_type = AccountType(payload.account_type.value)
    user = User(
        firebase_uid=payload.firebase_uid,
        email=payload.email.lower(),
        account_type=account_type,
        display_name=payload.display_name,
        role=_role_for_account(account_type),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return UserOut.from_user(user)


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.from_user(user)


@router.post("/me/password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def change_password(
    request: Request,
    payload: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash or not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid current password")
    if payload.current_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the current password",
        )
    user.password_hash = hash_password(payload.new_password)
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("password_changed", user_id=str(user.id))


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def logout_all(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("logout_all", user_id=str(user.id))


@router.get("/sessions", response_model=list[SessionOut])
async def list_sessions(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[SessionOut]:
    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked.is_(False))
        .order_by(RefreshToken.created_at.desc())
    )
    tokens = list(result.scalars().all())
    return [
        SessionOut(
            id=token.id,
            device_name=token.device_name or "Device",
            ip_address=token.ip_address,
            user_agent=token.user_agent,
            created_at=token.created_at,
            last_seen_at=token.last_seen_at,
            current=False,
        )
        for token in tokens
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_session(
    session_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    token = await session.get(RefreshToken, session_id)
    if token is None or token.user_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    token.revoked = True
    await session.commit()


@router.post("/verify-email/request", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def request_email_verification(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if user.email_verified_at is not None:
        return
    token = await _issue_auth_token(session, user.id, "email_verify", hours=48)
    await session.commit()
    email_service.send(
        to=user.email,
        subject="Verify your MarGem email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=token,
            intro="Verify your MarGem email address.",
        ),
    )


@router.post("/verify-email/confirm", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def confirm_email_verification(
    request: Request,
    payload: TokenConfirmRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(AuthToken).where(
            AuthToken.token_hash == _hash_token(payload.token),
            AuthToken.purpose == "email_verify",
        )
    )
    token = result.scalar_one_or_none()
    if token is None or token.used_at is not None or token.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")
    user = await session.get(User, token.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")
    user.email_verified_at = datetime.now(UTC)
    token.used_at = datetime.now(UTC)
    await session.commit()


@router.post("/password-reset/request", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def request_password_reset(
    request: Request,
    payload: EmailRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    # Always 204 to avoid account enumeration.
    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash:
        return
    token = await _issue_auth_token(session, user.id, "password_reset", hours=2)
    await session.commit()
    email_service.send(
        to=user.email,
        subject="Reset your MarGem password",
        text_body=_auth_action_body(
            path="/reset-password",
            token=token,
            intro="Reset your MarGem password. If you did not request this, ignore this email.",
        ),
    )


@router.post("/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def confirm_password_reset(
    request: Request,
    payload: PasswordResetConfirm,
    session: AsyncSession = Depends(get_db),
) -> None:
    try:
        validate_password_strength(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    result = await session.execute(
        select(AuthToken).where(
            AuthToken.token_hash == _hash_token(payload.token),
            AuthToken.purpose == "password_reset",
        )
    )
    token = result.scalar_one_or_none()
    if token is None or token.used_at is not None or token.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    user = await session.get(User, token.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    user.password_hash = hash_password(payload.new_password)
    token.used_at = datetime.now(UTC)
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("password_reset", user_id=str(user.id))


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def delete_account(
    request: Request,
    payload: DeleteAccountRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid password")

    from sqlalchemy import delete as sql_delete

    from app.models import (
        AuthToken,
        Conversation,
        Favorite,
        Message,
        Notification,
        RecentlyViewed,
        Review,
        SavedSearch,
        SellerFollow,
        Subscription,
    )

    seller = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    profile = seller.scalar_one_or_none()

    # Remove message history the user authored, then conversations they own as buyer.
    await session.execute(sql_delete(Message).where(Message.sender_id == user.id))
    buyer_conversations = (
        await session.execute(select(Conversation.id).where(Conversation.buyer_id == user.id))
    ).scalars().all()
    if buyer_conversations:
        await session.execute(sql_delete(Message).where(Message.conversation_id.in_(buyer_conversations)))
        await session.execute(sql_delete(Conversation).where(Conversation.id.in_(buyer_conversations)))

    if profile is not None:
        from app.models import Product, SellerCategory, Service

        seller_conversations = (
            await session.execute(select(Conversation.id).where(Conversation.seller_id == profile.id))
        ).scalars().all()
        if seller_conversations:
            await session.execute(sql_delete(Message).where(Message.conversation_id.in_(seller_conversations)))
            await session.execute(sql_delete(Conversation).where(Conversation.id.in_(seller_conversations)))
        # Clear association + owned rows before deleting the storefront (no ON DELETE CASCADE).
        await session.execute(sql_delete(SellerCategory).where(SellerCategory.seller_id == profile.id))
        await session.execute(sql_delete(Product).where(Product.seller_id == profile.id))
        await session.execute(sql_delete(Service).where(Service.seller_id == profile.id))
        await session.execute(sql_delete(Review).where(Review.seller_id == profile.id))
        await session.delete(profile)

    for model, column in (
        (Favorite, Favorite.user_id),
        (SellerFollow, SellerFollow.user_id),
        (SavedSearch, SavedSearch.user_id),
        (RecentlyViewed, RecentlyViewed.user_id),
        (Notification, Notification.user_id),
        (Subscription, Subscription.user_id),
        (AuthToken, AuthToken.user_id),
        (Review, Review.buyer_id),
    ):
        await session.execute(sql_delete(model).where(column == user.id))

    await revoke_all_refresh_tokens(session, user.id)
    user.status = UserStatus.DELETED
    user.email = f"deleted+{user.id}@invalid.local"
    user.display_name = "Deleted user"
    user.password_hash = None
    user.is_premium = False
    user.premium_until = None
    await session.commit()
    log_security_event("account_deleted", user_id=str(user.id))
