from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Notification


async def notify_user(
    session: AsyncSession,
    *,
    user_id: UUID,
    title: str,
    body: str = "",
    kind: str = "general",
    data: dict | None = None,
) -> Notification:
    notification = Notification(
        id=uuid4(),
        user_id=user_id,
        title=title,
        body=body,
        kind=kind,
        data=data or {},
        created_at=datetime.now(UTC),
    )
    session.add(notification)
    await session.flush()
    return notification
