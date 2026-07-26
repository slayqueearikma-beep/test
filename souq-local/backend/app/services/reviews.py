"""Eligibility for leaving a multi-category seller review.

MarGem does not process checkout, so it cannot prove an off-platform call or
WhatsApp interaction.  Ratings therefore require an attributable, server-side
storefront conversation containing a message from the prospective reviewer.
Client-reported contact clicks are analytics only and must never unlock trust
signals.
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Conversation, Message, Review, SellerProfile, User
from app.services.messaging import ordered_participants


async def has_completed_interaction(
    session: AsyncSession, *, user_id: UUID, seller: SellerProfile
) -> bool:
    a, b = ordered_participants(user_id, seller.user_id)
    conv = await session.scalar(
        select(Conversation.id).where(
            Conversation.participant_a_id == a,
            Conversation.participant_b_id == b,
            Conversation.context_seller_id == seller.id,
        )
    )
    if conv is None:
        return False

    message_count = await session.scalar(
        select(func.count(Message.id)).where(
            Message.conversation_id == conv,
            Message.sender_id == user_id,
        )
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
    if user.email_verified_at is None:
        return {
            "can_review": False,
            "reason": "email_unverified",
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
