import secrets
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import User
from app.services.security import decode_access_token

security = HTTPBearer(auto_error=False)


async def _resolve_user_from_credentials(
    credentials: HTTPAuthorizationCredentials | None,
    session: AsyncSession,
    *,
    required: bool,
) -> User | None:
    if settings.auth_dev_bypass and settings.app_env not in {"production", "prod"}:
        result = await session.execute(select(User).limit(1))
        user = result.scalar_one_or_none()
        if user is None and required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No users in database. Register first via POST /auth/register",
            )
        return user

    if credentials is None:
        if required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
        return None

    token = credentials.credentials

    # MarGem JWT (email/password accounts)
    user_id = decode_access_token(token)
    if user_id is not None:
        result = await session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            if required:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
            return None
        return user

    # Firebase ID token (mobile Firebase Auth)
    try:
        firebase_uid = await verify_firebase_token(token)
    except HTTPException:
        if required:
            raise
        return None

    result = await session.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()
    if user is None:
        if required:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not registered")
        return None
    return user


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_db),
) -> User:
    user = await _resolve_user_from_credentials(credentials, session, required=True)
    assert user is not None
    from app.models import UserStatus

    if getattr(user, "status", None) == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if getattr(user, "status", None) == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account deleted")
    return user


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_db),
) -> User | None:
    return await _resolve_user_from_credentials(credentials, session, required=False)


async def verify_firebase_token(token: str) -> str:
    try:
        import firebase_admin
        from firebase_admin import auth, credentials

        if not firebase_admin._apps:
            if settings.firebase_credentials_path:
                cred = credentials.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)
            else:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Firebase not configured",
                )

        decoded = auth.verify_id_token(token)
        return decoded["uid"]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


async def require_seller(user: User = Depends(get_current_user)) -> User:
    from app.models import AccountType

    if user.account_type != AccountType.SELLER:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Seller account required")
    return user


async def require_buyer(user: User = Depends(get_current_user)) -> User:
    from app.models import AccountType

    if user.account_type != AccountType.BUYER:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Buyer account required")
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    from app.models import UserRole

    if user.role not in {UserRole.ADMIN, UserRole.SUPPORT}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def new_local_firebase_uid() -> str:
    return f"local-{secrets.token_hex(16)}"
