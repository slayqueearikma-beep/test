"""Peer messaging helpers — any authenticated user can message any other user."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Conversation, Message, SellerProfile, User, UserStatus
from app.services.notifications import notify_user
from app.services.seller_counters import bump_inquiry_count


def ordered_participants(user_a: UUID, user_b: UUID) -> tuple[UUID, UUID]:
    if user_a == user_b:
        raise ValueError("participants must be distinct")
    return (user_a, user_b) if user_a.hex < user_b.hex else (user_b, user_a)


async def get_active_user(session: AsyncSession, user_id: UUID) -> User:
    user = await session.get(User, user_id)
    if user is None or getattr(user, "status", None) == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if getattr(user, "status", None) == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


async def find_conversation(
    session: AsyncSession, *, user_a: UUID, user_b: UUID
) -> Conversation | None:
    a, b = ordered_participants(user_a, user_b)
    result = await session.execute(
        select(Conversation).where(
            Conversation.participant_a_id == a,
            Conversation.participant_b_id == b,
        )
    )
    return result.scalar_one_or_none()


async def get_or_create_conversation(
    session: AsyncSession,
    *,
    initiator_id: UUID,
    peer_user_id: UUID,
    context_seller_id: UUID | None = None,
) -> tuple[Conversation, bool]:
    if initiator_id == peer_user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot message yourself")

    await get_active_user(session, peer_user_id)
    existing = await find_conversation(session, user_a=initiator_id, user_b=peer_user_id)
    if existing is not None:
        if context_seller_id is not None and existing.context_seller_id is None:
            existing.context_seller_id = context_seller_id
        return existing, False

    a, b = ordered_participants(initiator_id, peer_user_id)
    conversation = Conversation(
        id=uuid4(),
        participant_a_id=a,
        participant_b_id=b,
        context_seller_id=context_seller_id,
    )
    session.add(conversation)
    await session.flush()
    return conversation, True


async def send_message(
    session: AsyncSession,
    *,
    conversation: Conversation,
    sender: User,
    body: str,
    is_new: bool = False,
    notify_title: str = "New message",
) -> Message:
    if not conversation.involves(sender.id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

    message = Message(
        id=uuid4(),
        conversation_id=conversation.id,
        sender_id=sender.id,
        body=body,
    )
    conversation.last_message_at = datetime.now(UTC)
    session.add(message)

    peer_id = conversation.other_participant(sender.id)
    await notify_user(
        session,
        user_id=peer_id,
        title=notify_title,
        body=body[:120],
        kind="message",
        data={"conversation_id": str(conversation.id)},
    )

    if is_new and conversation.context_seller_id is not None:
        # Only bump when messaging a storefront context (not pure peer chats).
        store = await session.get(SellerProfile, conversation.context_seller_id)
        if store is not None and store.user_id == peer_id:
            await bump_inquiry_count(session, conversation.context_seller_id)

    await session.commit()
    await session.refresh(message)
    return message


async def require_conversation_participant(
    session: AsyncSession, conversation_id: UUID, user_id: UUID
) -> Conversation:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None or not conversation.involves(user_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    return conversation


async def peer_display_names(
    session: AsyncSession, peer_ids: set[UUID]
) -> dict[UUID, str]:
    if not peer_ids:
        return {}
    users = (await session.execute(select(User).where(User.id.in_(peer_ids)))).scalars().all()
    profiles = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id.in_(peer_ids)))
    ).scalars().all()
    business_by_user = {p.user_id: p.business_name for p in profiles}
    names: dict[UUID, str] = {}
    for user in users:
        names[user.id] = business_by_user.get(user.id) or user.display_name or user.email or "User"
    return names


def conversation_participant_filter(user_id: UUID):
    return or_(
        Conversation.participant_a_id == user_id,
        Conversation.participant_b_id == user_id,
    )
