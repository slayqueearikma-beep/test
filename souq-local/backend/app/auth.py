from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import User

security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_db),
) -> User:
    if settings.auth_dev_bypass:
        # Dev mode: accept X-Dev-User-Id header or default test user
        result = await session.execute(select(User).limit(1))
        user = result.scalar_one_or_none()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No users in database. Register first via POST /auth/register",
            )
        return user

    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

    firebase_uid = await verify_firebase_token(credentials.credentials)
    result = await session.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not registered")
    return user


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
