import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from jwt import InvalidTokenError
from passlib.context import CryptContext
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import RefreshToken
from app.services.audit import log_security_event

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=settings.bcrypt_rounds,
)

# Cap concurrent refresh sessions per user (login from many devices).
_MAX_REFRESH_SESSIONS = 10


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(user_id: UUID) -> str:
    expire = datetime.now(UTC) + timedelta(minutes=settings.jwt_access_expire_minutes)
    payload = {
        "sub": str(user_id),
        "exp": expire,
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> UUID | None:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        if payload.get("type") != "access":
            return None
        sub = payload.get("sub")
        if not sub:
            return None
        return UUID(sub)
    except (InvalidTokenError, ValueError, TypeError):
        return None


def _hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def revoke_all_refresh_tokens(session: AsyncSession, user_id: UUID) -> None:
    await session.execute(
        update(RefreshToken).where(RefreshToken.user_id == user_id).values(revoked=True)
    )


async def _prune_refresh_sessions(session: AsyncSession, user_id: UUID) -> None:
    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked.is_(False))
        .order_by(RefreshToken.created_at.desc())
    )
    tokens = list(result.scalars().all())
    for stale in tokens[_MAX_REFRESH_SESSIONS:]:
        stale.revoked = True


async def issue_refresh_token(session: AsyncSession, user_id: UUID) -> str:
    await _prune_refresh_sessions(session, user_id)
    plain = secrets.token_urlsafe(48)
    token = RefreshToken(
        user_id=user_id,
        token_hash=_hash_refresh_token(plain),
        expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expire_days),
    )
    session.add(token)
    await session.flush()
    return plain


async def rotate_refresh_token(session: AsyncSession, plain_token: str) -> tuple[UUID, str] | None:
    token_hash = _hash_refresh_token(plain_token)
    # Lock the token row so parallel refresh requests cannot both rotate the
    # same bearer credential before either transaction commits.
    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.token_hash == token_hash)
        .with_for_update()
    )
    stored = result.scalar_one_or_none()
    if stored is None:
        return None

    # Reuse of a revoked refresh token => possible theft; revoke entire family.
    if stored.revoked:
        log_security_event("refresh_reuse_detected", user_id=str(stored.user_id))
        await revoke_all_refresh_tokens(session, stored.user_id)
        return None

    if stored.expires_at < datetime.now(UTC):
        stored.revoked = True
        return None

    stored.revoked = True
    new_plain = await issue_refresh_token(session, stored.user_id)
    return stored.user_id, new_plain


async def revoke_refresh_token(session: AsyncSession, plain_token: str) -> None:
    token_hash = _hash_refresh_token(plain_token)
    result = await session.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    stored = result.scalar_one_or_none()
    if stored is not None:
        stored.revoked = True
