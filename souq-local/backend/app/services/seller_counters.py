"""Atomic seller profile counter helpers (avoid lost updates under concurrency)."""

from uuid import UUID

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SellerProfile


async def bump_favorite_count(session: AsyncSession, seller_id: UUID, *, delta: int) -> None:
    if delta == 0:
        return
    stmt = update(SellerProfile).where(SellerProfile.id == seller_id)
    if delta > 0:
        stmt = stmt.values(favorite_count=SellerProfile.favorite_count + delta)
    else:
        stmt = stmt.where(SellerProfile.favorite_count > 0).values(
            favorite_count=SellerProfile.favorite_count + delta
        )
    await session.execute(stmt)


async def bump_contact_click(session: AsyncSession, seller_id: UUID) -> None:
    await session.execute(
        update(SellerProfile)
        .where(SellerProfile.id == seller_id)
        .values(contact_click_count=SellerProfile.contact_click_count + 1)
    )


async def bump_inquiry_count(session: AsyncSession, seller_id: UUID) -> None:
    await session.execute(
        update(SellerProfile)
        .where(SellerProfile.id == seller_id)
        .values(inquiry_count=SellerProfile.inquiry_count + 1)
    )
