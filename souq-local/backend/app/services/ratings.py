from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Review, SellerProfile


def compute_achievement_stars(five_star_count: int) -> int:
    """One achievement star per 100 five-star reviews."""
    return five_star_count // 100


async def refresh_seller_ratings(session: AsyncSession, seller_id) -> None:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        return

    stats = await session.execute(
        select(
            func.count(Review.id),
            func.avg(Review.rating),
            func.count(Review.id).filter(Review.rating == 5),
        ).where(Review.seller_id == seller_id)
    )
    review_count, average_rating, five_star_count = stats.one()

    seller.review_count = int(review_count or 0)
    seller.average_rating = round(float(average_rating or 0.0), 2)
    seller.achievement_stars = compute_achievement_stars(int(five_star_count or 0))
    await session.commit()


async def get_seller_with_relations(session: AsyncSession, seller_id) -> SellerProfile | None:
    result = await session.execute(
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.products),
            selectinload(SellerProfile.services),
        )
        .where(SellerProfile.id == seller_id, SellerProfile.is_active.is_(True))
    )
    return result.scalar_one_or_none()
