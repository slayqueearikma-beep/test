from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, require_seller
from app.database import get_db
from app.models import Category, Product, Review, SellerProfile, Service, User
from app.schemas import (
    MapPin,
    ProductCreate,
    ProductOut,
    ReviewCreate,
    ReviewOut,
    SellerCreate,
    SellerDetail,
    SellerSummary,
    SellerUpdate,
    ServiceCreate,
    ServiceOut,
)
from app.services.ratings import refresh_seller_ratings

router = APIRouter(prefix="/sellers", tags=["sellers"])


@router.get("", response_model=list[SellerSummary])
async def list_sellers(
    city: str | None = None,
    category: str | None = None,
    q: str | None = None,
    session: AsyncSession = Depends(get_db),
) -> list[SellerProfile]:
    stmt = (
        select(SellerProfile)
        .options(selectinload(SellerProfile.categories))
        .where(SellerProfile.is_active.is_(True))
    )

    if city:
        stmt = stmt.where(SellerProfile.city.ilike(city))
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(
            or_(SellerProfile.business_name.ilike(pattern), SellerProfile.description.ilike(pattern))
        )
    if category:
        stmt = stmt.join(SellerProfile.categories).where(Category.slug == category)

    result = await session.execute(stmt.order_by(SellerProfile.average_rating.desc()))
    return list(result.scalars().unique().all())


@router.get("/map", response_model=list[MapPin])
async def map_pins(
    city: str | None = None,
    category: str | None = None,
    session: AsyncSession = Depends(get_db),
) -> list[MapPin]:
    sellers = await list_sellers(city=city, category=category, q=None, session=session)
    return [
        MapPin(
            id=s.id,
            business_name=s.business_name,
            latitude=s.latitude,
            longitude=s.longitude,
            achievement_stars=s.achievement_stars,
            average_rating=s.average_rating,
            category_slugs=[c.slug for c in s.categories],
        )
        for s in sellers
    ]


@router.post("", response_model=SellerDetail, status_code=status.HTTP_201_CREATED)
async def create_seller(
    payload: SellerCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SellerProfile:
    existing = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Seller profile already exists")

    categories = []
    if payload.category_ids:
        result = await session.execute(select(Category).where(Category.id.in_(payload.category_ids)))
        categories = list(result.scalars().all())

    seller = SellerProfile(
        user_id=user.id,
        business_name=payload.business_name,
        description=payload.description,
        address=payload.address,
        city=payload.city,
        latitude=payload.latitude,
        longitude=payload.longitude,
        phone=payload.phone,
        cover_image_url=payload.cover_image_url,
        categories=categories,
    )
    session.add(seller)
    await session.commit()

    detail = await session.execute(
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.products),
            selectinload(SellerProfile.services),
        )
        .where(SellerProfile.id == seller.id)
    )
    return detail.scalar_one()


@router.get("/{seller_id}", response_model=SellerDetail)
async def get_seller(seller_id: UUID, session: AsyncSession = Depends(get_db)) -> SellerProfile:
    result = await session.execute(
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.products),
            selectinload(SellerProfile.services),
        )
        .where(SellerProfile.id == seller_id, SellerProfile.is_active.is_(True))
    )
    seller = result.scalar_one_or_none()
    if seller is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")
    return seller


@router.patch("/{seller_id}", response_model=SellerDetail)
async def update_seller(
    seller_id: UUID,
    payload: SellerUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SellerProfile:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or seller.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    data = payload.model_dump(exclude_unset=True)
    category_ids = data.pop("category_ids", None)

    for key, value in data.items():
        setattr(seller, key, value)

    if category_ids is not None:
        result = await session.execute(select(Category).where(Category.id.in_(category_ids)))
        seller.categories = list(result.scalars().all())

    await session.commit()
    return await get_seller(seller_id, session)


@router.post("/{seller_id}/products", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
async def add_product(
    seller_id: UUID,
    payload: ProductCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Product:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or seller.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    product = Product(seller_id=seller_id, **payload.model_dump())
    session.add(product)
    await session.commit()
    await session.refresh(product)
    return product


@router.post("/{seller_id}/services", response_model=ServiceOut, status_code=status.HTTP_201_CREATED)
async def add_service(
    seller_id: UUID,
    payload: ServiceCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Service:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or seller.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    service = Service(seller_id=seller_id, **payload.model_dump())
    session.add(service)
    await session.commit()
    await session.refresh(service)
    return service


@router.get("/{seller_id}/reviews", response_model=list[ReviewOut])
async def list_reviews(seller_id: UUID, session: AsyncSession = Depends(get_db)) -> list[ReviewOut]:
    result = await session.execute(
        select(Review, User.display_name)
        .join(User, Review.buyer_id == User.id)
        .where(Review.seller_id == seller_id)
        .order_by(Review.created_at.desc())
    )
    return [
        ReviewOut(
            id=review.id,
            rating=review.rating,
            comment=review.comment,
            buyer_display_name=display_name or "Buyer",
            created_at=review.created_at,
        )
        for review, display_name in result.all()
    ]


@router.post("/{seller_id}/reviews", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    seller_id: UUID,
    payload: ReviewCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ReviewOut:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    existing = await session.execute(
        select(Review).where(Review.seller_id == seller_id, Review.buyer_id == user.id)
    )
    review = existing.scalar_one_or_none()
    if review:
        review.rating = payload.rating
        review.comment = payload.comment
    else:
        review = Review(seller_id=seller_id, buyer_id=user.id, **payload.model_dump())
        session.add(review)

    await session.commit()
    await refresh_seller_ratings(session, seller_id)
    await session.refresh(review)

    return ReviewOut(
        id=review.id,
        rating=review.rating,
        comment=review.comment,
        buyer_display_name=user.display_name or "Buyer",
        created_at=review.created_at,
    )
