from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Review, SellerProfile

# One achievement star per 100 overall five-star reviews.
# Every 1000 five-star reviews convert into one golden crown.
_STARS_PER_ACHIEVEMENT = 100
_FIVE_STARS_PER_CROWN = 1000


def compute_golden_crowns(five_star_count: int) -> int:
    """One golden crown per 1000 five-star (overall) reviews."""
    return max(0, int(five_star_count)) // _FIVE_STARS_PER_CROWN


def compute_achievement_stars(five_star_count: int) -> int:
    """One achievement star per 100 five-star reviews; remainder after crowns."""
    remaining = max(0, int(five_star_count)) % _FIVE_STARS_PER_CROWN
    return remaining // _STARS_PER_ACHIEVEMENT


def overall_from_categories(
    product_quality: int,
    customer_service: int,
    communication: int,
    trustworthiness: int,
) -> float:
    return round(
        (product_quality + customer_service + communication + trustworthiness) / 4.0,
        2,
    )


def rounded_overall(
    product_quality: int,
    customer_service: int,
    communication: int,
    trustworthiness: int,
) -> int:
    return int(
        round(
            overall_from_categories(
                product_quality, customer_service, communication, trustworthiness
            )
        )
    )


async def refresh_seller_ratings(session: AsyncSession, seller_id) -> None:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        return

    overall_expr = (
        Review.product_quality
        + Review.customer_service
        + Review.communication
        + Review.trustworthiness
    ) / 4.0

    stats = await session.execute(
        select(
            func.count(Review.id),
            func.avg(overall_expr),
            func.avg(Review.product_quality),
            func.avg(Review.customer_service),
            func.avg(Review.communication),
            func.avg(Review.trustworthiness),
            func.count(Review.id).filter(func.round(overall_expr) == 5),
        ).where(Review.seller_id == seller_id)
    )
    (
        review_count,
        average_rating,
        avg_product_quality,
        avg_customer_service,
        avg_communication,
        avg_trustworthiness,
        five_star_count,
    ) = stats.one()

    five_stars = int(five_star_count or 0)
    seller.review_count = int(review_count or 0)
    seller.average_rating = round(float(average_rating or 0.0), 2)
    seller.avg_product_quality = round(float(avg_product_quality or 0.0), 2)
    seller.avg_customer_service = round(float(avg_customer_service or 0.0), 2)
    seller.avg_communication = round(float(avg_communication or 0.0), 2)
    seller.avg_trustworthiness = round(float(avg_trustworthiness or 0.0), 2)
    seller.golden_crowns = compute_golden_crowns(five_stars)
    seller.achievement_stars = compute_achievement_stars(five_stars)
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
