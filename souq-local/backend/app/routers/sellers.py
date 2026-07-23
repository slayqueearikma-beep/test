from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, get_current_user_optional, require_seller
from app.config import settings
from app.database import get_db
from app.models import Category, Product, Review, SellerProfile, Service, User
from app.schemas import (
    MapPin,
    ProductCreate,
    ProductOut,
    ProductUpdate,
    ReviewCreate,
    ReviewEligibilityOut,
    ReviewOut,
    SellerCreate,
    SellerDashboardStats,
    SellerDetail,
    SellerSummary,
    SellerUpdate,
    ServiceCreate,
    ServiceOut,
    ServiceUpdate,
)
from app.services.ratings import (
    overall_from_categories,
    refresh_seller_ratings,
    rounded_overall,
)
from app.services.reviews import get_review_eligibility
from app.services.upload_security import validate_media_url

router = APIRouter(prefix="/sellers", tags=["sellers"])

_MAX_PAGE_SIZE = 100
_DEFAULT_PAGE_SIZE = 50


def _escape_ilike(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _opening_hours_dict(payload_hours) -> dict:
    if payload_hours is None:
        return {}
    return payload_hours.model_dump()


async def _load_seller_detail(session: AsyncSession, seller_id: UUID) -> SellerProfile:
    result = await session.execute(
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.products),
            selectinload(SellerProfile.services),
            selectinload(SellerProfile.user),
        )
        .where(SellerProfile.id == seller_id)
    )
    seller = result.scalar_one_or_none()
    if seller is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")
    from app.services.premium import apply_seller_premium_expiry

    before = seller.is_premium
    apply_seller_premium_expiry(seller, persist=True)
    if before and not seller.is_premium:
        await session.commit()
    return seller


async def _owned_seller(seller_id: UUID, user: User, session: AsyncSession) -> SellerProfile:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or seller.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")
    return seller


async def _seller_for_user(user: User, session: AsyncSession) -> SellerProfile:
    result = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    seller = result.scalar_one_or_none()
    if seller is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller profile not found")
    return seller


def _validate_owner_media(url: str, user_id: UUID) -> str:
    try:
        return validate_media_url(
            url or "",
            owner_user_id=user_id,
            container=settings.azure_storage_container,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


def _validate_owner_media_list(urls: list[str], user_id: UUID) -> list[str]:
    return [_validate_owner_media(u, user_id) for u in urls if u and str(u).strip()]


def _validate_optional_http_url(url: str, *, field: str) -> str:
    from app.schemas import _validate_http_url

    try:
        return _validate_http_url(url or "", field_name=field)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


def _public_product_visible(product: Product) -> bool:
    return (
        not bool(getattr(product, "is_hidden", False))
        and bool(getattr(product, "is_available", True))
        and not bool(getattr(product, "is_paused", False))
    )


@router.get("", response_model=list[SellerSummary])
async def list_sellers(
    city: str | None = None,
    category: str | None = None,
    q: str | None = None,
    limit: int = Query(default=_DEFAULT_PAGE_SIZE, ge=1, le=_MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
) -> list[SellerProfile]:
    stmt = (
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.user),
        )
        .where(SellerProfile.is_active.is_(True))
    )

    if city:
        safe_city = _escape_ilike(city[:80])
        stmt = stmt.where(SellerProfile.city.ilike(safe_city))
    if q:
        safe_q = _escape_ilike(q[:120])
        pattern = f"%{safe_q}%"
        stmt = stmt.where(
            or_(SellerProfile.business_name.ilike(pattern), SellerProfile.description.ilike(pattern))
        )
    if category:
        stmt = stmt.join(SellerProfile.categories).where(Category.slug == category)

    result = await session.execute(
        stmt.order_by(
            SellerProfile.is_premium.desc(),
            SellerProfile.average_rating.desc(),
        )
        .limit(limit)
        .offset(offset)
    )
    sellers = list(result.scalars().unique().all())
    from app.services.premium import apply_seller_premium_expiry

    dirty = False
    for seller in sellers:
        before = seller.is_premium
        apply_seller_premium_expiry(seller, persist=True)
        if before and not seller.is_premium:
            dirty = True
    if dirty:
        await session.commit()
    # Prefer still-premium first after expiry corrections.
    sellers.sort(key=lambda s: (not s.is_premium, -(s.average_rating or 0.0)))
    return sellers


@router.get("/map", response_model=list[MapPin])
async def map_pins(
    city: str | None = None,
    category: str | None = None,
    session: AsyncSession = Depends(get_db),
) -> list[MapPin]:
    sellers = await list_sellers(
        city=city, category=category, q=None, limit=_MAX_PAGE_SIZE, offset=0, session=session
    )
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


@router.get("/me", response_model=SellerDetail)
async def get_my_seller(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SellerProfile:
    seller = await _seller_for_user(user, session)
    return await _load_seller_detail(session, seller.id)


@router.get("/me/dashboard", response_model=SellerDashboardStats)
async def get_my_dashboard(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SellerDashboardStats:
    seller = await _seller_for_user(user, session)

    product_count = await session.scalar(
        select(func.count(Product.id)).where(Product.seller_id == seller.id)
    )
    available_product_count = await session.scalar(
        select(func.count(Product.id)).where(
            Product.seller_id == seller.id, Product.is_available.is_(True)
        )
    )
    service_count = await session.scalar(
        select(func.count(Service.id)).where(Service.seller_id == seller.id)
    )

    week_ago = datetime.now(timezone.utc) - timedelta(days=7)
    recent_review_count = await session.scalar(
        select(func.count(Review.id)).where(
            Review.seller_id == seller.id, Review.created_at >= week_ago
        )
    )

    return SellerDashboardStats(
        seller_id=seller.id,
        business_name=seller.business_name,
        profile_view_count=seller.profile_view_count,
        product_count=int(product_count or 0),
        available_product_count=int(available_product_count or 0),
        service_count=int(service_count or 0),
        review_count=seller.review_count,
        average_rating=seller.average_rating,
        achievement_stars=seller.achievement_stars,
        recent_review_count=int(recent_review_count or 0),
        inquiry_count=int(seller.inquiry_count or 0),
        favorite_count=int(seller.favorite_count or 0),
        contact_click_count=int(seller.contact_click_count or 0),
        avg_response_minutes=int(seller.avg_response_minutes or 0),
        is_premium=bool(seller.is_premium),
        verification_status=seller.verification_status.value
        if hasattr(seller.verification_status, "value")
        else str(seller.verification_status),
        is_active=seller.is_active,
    )


@router.post("", response_model=SellerDetail, status_code=status.HTTP_201_CREATED)
async def create_seller(
    payload: SellerCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SellerProfile:
    """Create a storefront on the current account (buyer can upgrade in place)."""
    from app.models import AccountType, UserRole

    existing = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Seller profile already exists")

    categories = []
    if payload.category_ids:
        result = await session.execute(select(Category).where(Category.id.in_(payload.category_ids)))
        categories = list(result.scalars().all())

    cover = _validate_owner_media(payload.cover_image_url, user.id)
    logo = _validate_owner_media(payload.logo_image_url, user.id)

    seller = SellerProfile(
        user_id=user.id,
        business_name=payload.business_name,
        description=payload.description,
        address=payload.address,
        city=payload.city,
        latitude=payload.latitude,
        longitude=payload.longitude,
        phone=payload.phone,
        cover_image_url=cover,
        logo_image_url=logo,
        opening_hours=_opening_hours_dict(payload.opening_hours),
        website_url=_validate_optional_http_url(payload.website_url, field="website_url"),
        instagram_url=_validate_optional_http_url(payload.instagram_url, field="instagram_url"),
        facebook_url=_validate_optional_http_url(payload.facebook_url, field="facebook_url"),
        tiktok_url=_validate_optional_http_url(payload.tiktok_url, field="tiktok_url"),
        whatsapp_number=payload.whatsapp_number.strip() or payload.phone.strip(),
        payment_methods=payload.payment_methods or ["cash"],
        delivery_methods=payload.delivery_methods or ["in_store"],
        service_areas=payload.service_areas or [],
        categories=categories,
    )
    session.add(seller)
    # Dual-mode: keep one identity; mark account as seller-capable.
    user.account_type = AccountType.SELLER
    user.role = UserRole.SELLER
    await session.commit()
    return await _load_seller_detail(session, seller.id)


@router.get("/{seller_id}", response_model=SellerDetail)
async def get_seller(
    seller_id: UUID,
    session: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_current_user_optional),
) -> SellerProfile:
    seller = await _load_seller_detail(session, seller_id)
    is_owner = user is not None and user.id == seller.user_id
    if not seller.is_active and not is_owner:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    # Count public views; skip when the owner is browsing their own storefront.
    if not is_owner:
        from sqlalchemy import update as sql_update

        await session.execute(
            sql_update(SellerProfile)
            .where(SellerProfile.id == seller_id)
            .values(profile_view_count=SellerProfile.profile_view_count + 1)
        )
        await session.commit()
        seller = await _load_seller_detail(session, seller_id)
        # Hide moderated / unavailable / paused inventory from public shoppers.
        seller.products = [p for p in seller.products if _public_product_visible(p)]
        seller.services = [s for s in seller.services if s.is_available]

    return seller


@router.patch("/{seller_id}", response_model=SellerDetail)
async def update_seller(
    seller_id: UUID,
    payload: SellerUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SellerProfile:
    seller = await _owned_seller(seller_id, user, session)

    data = payload.model_dump(exclude_unset=True)
    category_ids = data.pop("category_ids", None)
    opening_hours = data.pop("opening_hours", None)

    if "cover_image_url" in data:
        data["cover_image_url"] = _validate_owner_media(data["cover_image_url"] or "", user.id)
    if "logo_image_url" in data:
        data["logo_image_url"] = _validate_owner_media(data["logo_image_url"] or "", user.id)
    for url_field in ("website_url", "instagram_url", "facebook_url", "tiktok_url"):
        if url_field in data and data[url_field] is not None:
            data[url_field] = _validate_optional_http_url(data[url_field] or "", field=url_field)
    if opening_hours is not None:
        data["opening_hours"] = opening_hours

    for key, value in data.items():
        setattr(seller, key, value)

    if category_ids is not None:
        result = await session.execute(select(Category).where(Category.id.in_(category_ids)))
        seller.categories = list(result.scalars().all())

    await session.commit()
    return await _load_seller_detail(session, seller_id)


@router.post("/{seller_id}/products", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
async def add_product(
    seller_id: UUID,
    payload: ProductCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Product:
    await _owned_seller(seller_id, user, session)

    image_url = _validate_owner_media(payload.image_url, user.id)
    product_data = payload.model_dump()
    product_data["image_url"] = image_url
    product_data["media_urls"] = _validate_owner_media_list(list(payload.media_urls or []), user.id)
    product_data["video_url"] = _validate_owner_media(payload.video_url or "", user.id)
    if payload.is_featured and not user.is_premium:
        # Featured placement is a premium visibility perk.
        product_data["is_featured"] = False
    product = Product(seller_id=seller_id, **product_data)
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
    await _owned_seller(seller_id, user, session)

    image_url = _validate_owner_media(payload.image_url, user.id)
    service_data = payload.model_dump()
    service_data["image_url"] = image_url
    service = Service(seller_id=seller_id, **service_data)
    session.add(service)
    await session.commit()
    await session.refresh(service)
    return service


@router.patch("/{seller_id}/products/{product_id}", response_model=ProductOut)
async def update_product(
    seller_id: UUID,
    product_id: UUID,
    payload: ProductUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Product:
    await _owned_seller(seller_id, user, session)
    product = await session.get(Product, product_id)
    if product is None or product.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    data = payload.model_dump(exclude_unset=True)
    if "image_url" in data:
        data["image_url"] = _validate_owner_media(data["image_url"] or "", user.id)
    if "media_urls" in data and data["media_urls"] is not None:
        data["media_urls"] = _validate_owner_media_list(list(data["media_urls"] or []), user.id)
    if "video_url" in data:
        data["video_url"] = _validate_owner_media(data["video_url"] or "", user.id)
    if data.get("is_featured") is True and not user.is_premium:
        data["is_featured"] = False

    for key, value in data.items():
        setattr(product, key, value)
    await session.commit()
    await session.refresh(product)
    return product


@router.delete("/{seller_id}/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    seller_id: UUID,
    product_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> None:
    await _owned_seller(seller_id, user, session)
    product = await session.get(Product, product_id)
    if product is None or product.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    await session.delete(product)
    await session.commit()


@router.post(
    "/{seller_id}/products/{product_id}/duplicate",
    response_model=ProductOut,
    status_code=status.HTTP_201_CREATED,
)
async def duplicate_product(
    seller_id: UUID,
    product_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Product:
    await _owned_seller(seller_id, user, session)
    product = await session.get(Product, product_id)
    if product is None or product.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    clone = Product(
        seller_id=seller_id,
        name=f"{product.name} (copy)",
        description=product.description,
        price_mad=product.price_mad,
        price_negotiable=product.price_negotiable,
        availability_note=product.availability_note,
        accepted_payment_methods=list(product.accepted_payment_methods or []),
        delivery_options=list(product.delivery_options or []),
        image_url=product.image_url,
        media_urls=list(product.media_urls or []),
        video_url=product.video_url,
        category_slug=product.category_slug,
        stock_quantity=product.stock_quantity,
        is_available=False,
        is_hidden=True,
        is_featured=False,
        is_paused=True,
    )
    session.add(clone)
    await session.commit()
    await session.refresh(clone)
    return clone


@router.patch("/{seller_id}/services/{service_id}", response_model=ServiceOut)
async def update_service(
    seller_id: UUID,
    service_id: UUID,
    payload: ServiceUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> Service:
    await _owned_seller(seller_id, user, session)
    service = await session.get(Service, service_id)
    if service is None or service.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    data = payload.model_dump(exclude_unset=True)
    if "image_url" in data:
        data["image_url"] = _validate_owner_media(data["image_url"] or "", user.id)

    for key, value in data.items():
        setattr(service, key, value)
    await session.commit()
    await session.refresh(service)
    return service


@router.delete("/{seller_id}/services/{service_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_service(
    seller_id: UUID,
    service_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> None:
    await _owned_seller(seller_id, user, session)
    service = await session.get(Service, service_id)
    if service is None or service.seller_id != seller_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    await session.delete(service)
    await session.commit()


def _review_out(review: Review, buyer_display_name: str) -> ReviewOut:
    return ReviewOut(
        id=review.id,
        rating=review.rating,
        overall_rating=overall_from_categories(
            review.product_quality,
            review.customer_service,
            review.communication,
            review.trustworthiness,
        ),
        product_quality=review.product_quality,
        customer_service=review.customer_service,
        communication=review.communication,
        trustworthiness=review.trustworthiness,
        comment=review.comment,
        buyer_display_name=buyer_display_name or "Buyer",
        created_at=review.created_at,
    )


@router.get("/{seller_id}/reviews/eligibility", response_model=ReviewEligibilityOut)
async def review_eligibility(
    seller_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ReviewEligibilityOut:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")
    return ReviewEligibilityOut(**await get_review_eligibility(session, user=user, seller=seller))


@router.get("/{seller_id}/reviews", response_model=list[ReviewOut])
async def list_reviews(
    seller_id: UUID,
    limit: int = Query(default=_DEFAULT_PAGE_SIZE, ge=1, le=_MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
) -> list[ReviewOut]:
    result = await session.execute(
        select(Review, User.display_name)
        .join(User, Review.buyer_id == User.id)
        .where(Review.seller_id == seller_id)
        .order_by(Review.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return [
        _review_out(review, display_name or "Buyer")
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
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    eligibility = await get_review_eligibility(session, user=user, seller=seller)
    if not eligibility["can_review"]:
        detail = (
            "Cannot review your own business"
            if eligibility["reason"] == "own_store"
            else "A completed interaction with this seller is required before reviewing"
        )
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)

    overall = rounded_overall(
        payload.product_quality,
        payload.customer_service,
        payload.communication,
        payload.trustworthiness,
    )
    comment = (payload.comment or "").strip()

    existing = await session.execute(
        select(Review).where(Review.seller_id == seller_id, Review.buyer_id == user.id)
    )
    review = existing.scalar_one_or_none()
    if review:
        review.product_quality = payload.product_quality
        review.customer_service = payload.customer_service
        review.communication = payload.communication
        review.trustworthiness = payload.trustworthiness
        review.rating = overall
        review.comment = comment
    else:
        review = Review(
            seller_id=seller_id,
            buyer_id=user.id,
            product_quality=payload.product_quality,
            customer_service=payload.customer_service,
            communication=payload.communication,
            trustworthiness=payload.trustworthiness,
            rating=overall,
            comment=comment,
        )
        session.add(review)

    await session.commit()
    await refresh_seller_ratings(session, seller_id)
    await session.refresh(review)

    return _review_out(review, user.display_name or "Buyer")
