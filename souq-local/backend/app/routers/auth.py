from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, new_local_firebase_uid
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AccountType, SellerProfile, User
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


async def _token_response(session: AsyncSession, user: User) -> TokenResponse:
    refresh_token = await issue_refresh_token(session, user.id)
    await session.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.model_validate(user),
    )


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
        log_security_event("register_conflict", email=payload.email.lower())
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        firebase_uid=new_local_firebase_uid(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        account_type=AccountType(payload.account_type.value),
        display_name=payload.display_name.strip(),
    )
    session.add(user)
    await session.flush()
    log_security_event("register_success", user_id=str(user.id), account_type=user.account_type.value)
    return await _token_response(session, user)


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
        log_security_event("login_failed", email=payload.email.lower(), client=request.client.host if request.client else "unknown")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    log_security_event("login_success", user_id=str(user.id))
    return await _token_response(session, user)


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

    user_id, _new_refresh = rotated
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    await session.commit()
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=_new_refresh,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.model_validate(user),
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
) -> User:
    if settings.app_env in {"production", "prod"} or not settings.debug:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not available")

    existing = await session.execute(
        select(User).where((User.firebase_uid == payload.firebase_uid) | (User.email == payload.email.lower()))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

    user = User(
        firebase_uid=payload.firebase_uid,
        email=payload.email.lower(),
        account_type=AccountType(payload.account_type.value),
        display_name=payload.display_name,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> User:
    return user


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

    seller = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    profile = seller.scalar_one_or_none()
    if profile is not None:
        await session.delete(profile)

    from app.models import Review

    buyer_reviews = await session.execute(select(Review).where(Review.buyer_id == user.id))
    for review in buyer_reviews.scalars().all():
        await session.delete(review)

    await revoke_all_refresh_tokens(session, user.id)
    await session.delete(user)
    await session.commit()
    log_security_event("account_deleted", user_id=str(user.id))
