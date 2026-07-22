"""Discovery platform APIs: favorites, follows, contact, reports — no cart/checkout/orders."""

from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, get_current_user_optional
from app.database import get_db
from app.limiter import limiter
from app.models import (
    ContactEvent,
    Favorite,
    Product,
    RecentlyViewed,
    Report,
    SavedSearch,
    SellerFollow,
    SellerProfile,
    User,
)
from app.services.seller_counters import (
    bump_contact_click,
    bump_favorite_count,
    bump_inquiry_count,
)

router = APIRouter(tags=["discovery"])


class FavoriteOut(BaseModel):
    id: UUID
    product_id: UUID | None = None
    seller_id: UUID | None = None
    product_name: str = ""
    image_url: str = ""
    price_mad: float | None = None
    seller_name: str = ""
    city: str = ""


class GuestFavoriteItem(BaseModel):
    product_id: UUID | None = None
    seller_id: UUID | None = None


class GuestFavoritesMigrate(BaseModel):
    items: list[GuestFavoriteItem] = Field(default_factory=list, max_length=50)


class FollowOut(BaseModel):
    id: UUID
    seller_id: UUID
    business_name: str
    city: str
    logo_image_url: str = ""
    average_rating: float = 0
    is_premium: bool = False
    verification_status: str = "unverified"


class SavedSearchCreate(BaseModel):
    query: str = Field(default="", max_length=160)
    city: str = Field(default="", max_length=80)
    category: str = Field(default="", max_length=80)


class SavedSearchOut(BaseModel):
    id: UUID
    query: str
    city: str
    category: str

    model_config = {"from_attributes": True}


class RecentlyViewedOut(BaseModel):
    id: UUID
    seller_id: UUID | None = None
    product_id: UUID | None = None
    title: str = ""
    image_url: str = ""
    subtitle: str = ""


class ReportCreate(BaseModel):
    seller_id: UUID | None = None
    product_id: UUID | None = None
    reason: str = Field(min_length=3, max_length=80)
    details: str = Field(default="", max_length=2000)


class ContactEventCreate(BaseModel):
    seller_id: UUID
    channel: str = Field(pattern="^(call|whatsapp|email|message|website|sms)$")


def _favorite_out(fav: Favorite) -> FavoriteOut:
    product = fav.product
    seller = fav.seller or (product.seller if product is not None else None)
    return FavoriteOut(
        id=fav.id,
        product_id=fav.product_id,
        seller_id=fav.seller_id or (product.seller_id if product else None),
        product_name=product.name if product else "",
        image_url=(product.image_url if product else "") or (seller.logo_image_url if seller else ""),
        price_mad=product.price_mad if product else None,
        seller_name=seller.business_name if seller else "",
        city=seller.city if seller else "",
    )


@router.get("/favorites", response_model=list[FavoriteOut])
async def list_favorites(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[FavoriteOut]:
    result = await session.execute(
        select(Favorite)
        .options(
            selectinload(Favorite.product).selectinload(Product.seller),
            selectinload(Favorite.seller),
        )
        .where(Favorite.user_id == user.id)
        .order_by(Favorite.created_at.desc())
    )
    return [_favorite_out(f) for f in result.scalars().all()]


@router.post("/favorites/products/{product_id}", response_model=FavoriteOut, status_code=status.HTTP_201_CREATED)
async def add_favorite_product(
    product_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FavoriteOut:
    product = await session.get(Product, product_id)
    if product is None or product.is_hidden:
        raise HTTPException(status_code=404, detail="Listing not found")
    existing = await session.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.product_id == product_id)
    )
    fav = existing.scalar_one_or_none()
    if fav is None:
        fav = Favorite(id=uuid4(), user_id=user.id, product_id=product_id, seller_id=product.seller_id)
        session.add(fav)
        await bump_favorite_count(session, product.seller_id, delta=1)
        await session.commit()
    result = await session.execute(
        select(Favorite)
        .options(selectinload(Favorite.product).selectinload(Product.seller), selectinload(Favorite.seller))
        .where(Favorite.id == fav.id)
    )
    return _favorite_out(result.scalar_one())


@router.delete("/favorites/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite_product(
    product_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.product_id == product_id)
    )
    fav = result.scalar_one_or_none()
    if fav is None:
        return
    seller_id = fav.seller_id
    await session.delete(fav)
    if seller_id:
        await bump_favorite_count(session, seller_id, delta=-1)
    await session.commit()


@router.post("/favorites/sellers/{seller_id}", response_model=FavoriteOut, status_code=status.HTTP_201_CREATED)
async def add_favorite_seller(
    seller_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FavoriteOut:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not found")
    existing = await session.execute(
        select(Favorite).where(
            Favorite.user_id == user.id,
            Favorite.seller_id == seller_id,
            Favorite.product_id.is_(None),
        )
    )
    fav = existing.scalar_one_or_none()
    if fav is None:
        fav = Favorite(id=uuid4(), user_id=user.id, seller_id=seller_id)
        session.add(fav)
        await bump_favorite_count(session, seller_id, delta=1)
        await session.commit()
    result = await session.execute(
        select(Favorite).options(selectinload(Favorite.seller)).where(Favorite.id == fav.id)
    )
    return _favorite_out(result.scalar_one())


@router.delete("/favorites/sellers/{seller_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite_seller(
    seller_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(Favorite).where(
            Favorite.user_id == user.id,
            Favorite.seller_id == seller_id,
            Favorite.product_id.is_(None),
        )
    )
    fav = result.scalar_one_or_none()
    if fav is None:
        return
    await session.delete(fav)
    await bump_favorite_count(session, seller_id, delta=-1)
    await session.commit()


@router.post("/favorites/migrate-guest", response_model=list[FavoriteOut])
async def migrate_guest_favorites(
    payload: GuestFavoritesMigrate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[FavoriteOut]:
    for item in payload.items:
        if item.product_id:
            product = await session.get(Product, item.product_id)
            if product is None or product.is_hidden:
                continue
            exists = await session.execute(
                select(Favorite).where(Favorite.user_id == user.id, Favorite.product_id == item.product_id)
            )
            if exists.scalar_one_or_none() is None:
                session.add(
                    Favorite(
                        id=uuid4(),
                        user_id=user.id,
                        product_id=item.product_id,
                        seller_id=product.seller_id,
                    )
                )
                await bump_favorite_count(session, product.seller_id, delta=1)
        elif item.seller_id:
            seller = await session.get(SellerProfile, item.seller_id)
            if seller is None:
                continue
            exists = await session.execute(
                select(Favorite).where(
                    Favorite.user_id == user.id,
                    Favorite.seller_id == item.seller_id,
                    Favorite.product_id.is_(None),
                )
            )
            if exists.scalar_one_or_none() is None:
                session.add(Favorite(id=uuid4(), user_id=user.id, seller_id=item.seller_id))
                await bump_favorite_count(session, item.seller_id, delta=1)
    await session.commit()
    return await list_favorites(user=user, session=session)


@router.get("/follows", response_model=list[FollowOut])
async def list_follows(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[FollowOut]:
    result = await session.execute(
        select(SellerFollow, SellerProfile)
        .join(SellerProfile, SellerProfile.id == SellerFollow.seller_id)
        .where(SellerFollow.user_id == user.id)
        .order_by(SellerFollow.created_at.desc())
    )
    rows = result.all()
    return [
        FollowOut(
            id=follow.id,
            seller_id=seller.id,
            business_name=seller.business_name,
            city=seller.city,
            logo_image_url=seller.logo_image_url,
            average_rating=seller.average_rating,
            is_premium=seller.is_premium,
            verification_status=seller.verification_status.value
            if hasattr(seller.verification_status, "value")
            else str(seller.verification_status),
        )
        for follow, seller in rows
    ]


@router.post("/follows/sellers/{seller_id}", response_model=FollowOut, status_code=status.HTTP_201_CREATED)
async def follow_seller(
    seller_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> FollowOut:
    seller = await session.get(SellerProfile, seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not found")
    if seller.user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot follow your own business")
    existing = await session.execute(
        select(SellerFollow).where(SellerFollow.user_id == user.id, SellerFollow.seller_id == seller_id)
    )
    follow = existing.scalar_one_or_none()
    if follow is None:
        follow = SellerFollow(id=uuid4(), user_id=user.id, seller_id=seller_id)
        session.add(follow)
        await session.commit()
        await session.refresh(follow)
    return FollowOut(
        id=follow.id,
        seller_id=seller.id,
        business_name=seller.business_name,
        city=seller.city,
        logo_image_url=seller.logo_image_url,
        average_rating=seller.average_rating,
        is_premium=seller.is_premium,
        verification_status=seller.verification_status.value
        if hasattr(seller.verification_status, "value")
        else str(seller.verification_status),
    )


@router.delete("/follows/sellers/{seller_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow_seller(
    seller_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(SellerFollow).where(SellerFollow.user_id == user.id, SellerFollow.seller_id == seller_id)
    )
    follow = result.scalar_one_or_none()
    if follow:
        await session.delete(follow)
        await session.commit()


@router.get("/saved-searches", response_model=list[SavedSearchOut])
async def list_saved_searches(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[SavedSearch]:
    result = await session.execute(
        select(SavedSearch).where(SavedSearch.user_id == user.id).order_by(SavedSearch.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("/saved-searches", response_model=SavedSearchOut, status_code=status.HTTP_201_CREATED)
async def create_saved_search(
    payload: SavedSearchCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SavedSearch:
    row = SavedSearch(
        id=uuid4(),
        user_id=user.id,
        query=payload.query.strip(),
        city=payload.city.strip(),
        category=payload.category.strip(),
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


@router.delete("/saved-searches/{search_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_saved_search(
    search_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    row = await session.get(SavedSearch, search_id)
    if row is None or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Saved search not found")
    await session.delete(row)
    await session.commit()


@router.get("/recently-viewed", response_model=list[RecentlyViewedOut])
async def list_recently_viewed(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=20, ge=1, le=50),
) -> list[RecentlyViewedOut]:
    result = await session.execute(
        select(RecentlyViewed)
        .where(RecentlyViewed.user_id == user.id)
        .order_by(RecentlyViewed.viewed_at.desc())
        .limit(limit)
    )
    items: list[RecentlyViewedOut] = []
    for row in result.scalars().all():
        title = ""
        image_url = ""
        subtitle = ""
        if row.product_id:
            product = await session.get(Product, row.product_id)
            if product:
                title = product.name
                image_url = product.image_url
                seller = await session.get(SellerProfile, product.seller_id)
                subtitle = seller.business_name if seller else ""
        elif row.seller_id:
            seller = await session.get(SellerProfile, row.seller_id)
            if seller:
                title = seller.business_name
                image_url = seller.logo_image_url or seller.cover_image_url
                subtitle = seller.city
        items.append(
            RecentlyViewedOut(
                id=row.id,
                seller_id=row.seller_id,
                product_id=row.product_id,
                title=title,
                image_url=image_url,
                subtitle=subtitle,
            )
        )
    return items


@router.post("/recently-viewed", status_code=status.HTTP_204_NO_CONTENT)
async def track_recently_viewed(
    seller_id: UUID | None = None,
    product_id: UUID | None = None,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not seller_id and not product_id:
        raise HTTPException(status_code=400, detail="Provide seller_id or product_id")
    if product_id is not None:
        product = await session.get(Product, product_id)
        if product is None or product.is_hidden:
            raise HTTPException(status_code=404, detail="Listing not found")
        if seller_id is None:
            seller_id = product.seller_id
    if seller_id is not None:
        seller = await session.get(SellerProfile, seller_id)
        if seller is None:
            raise HTTPException(status_code=404, detail="Seller not found")
    session.add(
        RecentlyViewed(
            id=uuid4(),
            user_id=user.id,
            seller_id=seller_id,
            product_id=product_id,
        )
    )
    await session.commit()


@router.post("/reports", status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def create_report(
    request: Request,
    payload: ReportCreate,
    session: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_current_user_optional),
) -> dict:
    if not payload.seller_id and not payload.product_id:
        raise HTTPException(status_code=400, detail="Provide seller_id or product_id")
    if payload.product_id is not None:
        product = await session.get(Product, payload.product_id)
        if product is None:
            raise HTTPException(status_code=404, detail="Listing not found")
    if payload.seller_id is not None:
        seller = await session.get(SellerProfile, payload.seller_id)
        if seller is None:
            raise HTTPException(status_code=404, detail="Seller not found")
    reason = payload.reason.strip()
    if not reason or len(reason) > 80:
        raise HTTPException(status_code=400, detail="Invalid report reason")
    report = Report(
        id=uuid4(),
        reporter_id=user.id if user else None,
        seller_id=payload.seller_id,
        product_id=payload.product_id,
        reason=reason,
        details=(payload.details or "").strip()[:2000],
    )
    session.add(report)
    await session.commit()
    return {"id": str(report.id), "status": "open"}


@router.post("/contact-events", status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def create_contact_event(
    request: Request,
    payload: ContactEventCreate,
    session: AsyncSession = Depends(get_db),
    user: User | None = Depends(get_current_user_optional),
) -> dict:
    seller = await session.get(SellerProfile, payload.seller_id)
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller not found")
    allowed = {"call", "whatsapp", "email", "message", "website", "sms"}
    if payload.channel not in allowed:
        raise HTTPException(status_code=400, detail="Invalid contact channel")
    event = ContactEvent(
        id=uuid4(),
        seller_id=payload.seller_id,
        user_id=user.id if user else None,
        channel=payload.channel,
    )
    session.add(event)
    await bump_contact_click(session, payload.seller_id)
    if payload.channel == "message":
        await bump_inquiry_count(session, payload.seller_id)
    await session.commit()
    return {"id": str(event.id), "channel": payload.channel}
