"""Eligibility for leaving a multi-category seller review.

MarGem has no cart/checkout. A "completed transaction" is evidenced by a real
interaction with the seller storefront: an authenticated contact event
(call / WhatsApp / in-app message) or a conversation with at least one message
scoped to that storefront.
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import ContactEvent, Conversation, Message, Review, SellerProfile, User
from app.services.messaging import ordered_participants


async def has_completed_interaction(
    session: AsyncSession, *, user_id: UUID, seller: SellerProfile
) -> bool:
    contact = await session.scalar(
        select(ContactEvent.id)
        .where(
            ContactEvent.seller_id == seller.id,
            ContactEvent.user_id == user_id,
            ContactEvent.channel.in_(("call", "whatsapp", "message")),
        )
        .limit(1)
    )
    if contact is not None:
        return True

    a, b = ordered_participants(user_id, seller.user_id)
    conv = await session.scalar(
        select(Conversation.id).where(
            Conversation.participant_a_id == a,
            Conversation.participant_b_id == b,
            or_(
                Conversation.context_seller_id == seller.id,
                Conversation.context_seller_id.is_(None),
            ),
        )
    )
    if conv is None:
        return False

    message_count = await session.scalar(
        select(func.count(Message.id)).where(Message.conversation_id == conv)
    )
    return int(message_count or 0) > 0


async def get_review_eligibility(
    session: AsyncSession, *, user: User, seller: SellerProfile
) -> dict:
    if seller.user_id == user.id:
        return {
            "can_review": False,
            "reason": "own_store",
            "has_reviewed": False,
        }

    existing = await session.scalar(
        select(Review.id).where(Review.seller_id == seller.id, Review.buyer_id == user.id)
    )
    has_reviewed = existing is not None

    if not await has_completed_interaction(session, user_id=user.id, seller=seller):
        return {
            "can_review": False,
            "reason": "no_completed_transaction",
            "has_reviewed": has_reviewed,
        }

    return {
        "can_review": True,
        "reason": "ok",
        "has_reviewed": has_reviewed,
    }
