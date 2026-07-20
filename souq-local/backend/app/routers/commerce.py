from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import (
    BuyerAddress,
    CartItem,
    Order,
    OrderItem,
    OrderStatus,
    PaymentStatus,
    Product,
    SellerProfile,
    User,
    WishlistItem,
)
from app.services.notifications import notify_user

router = APIRouter(tags=["commerce"])


class AddressCreate(BaseModel):
    label: str = Field(default="Home", max_length=80)
    recipient_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=6, max_length=32)
    address_line1: str = Field(min_length=5, max_length=255)
    city: str = Field(min_length=2, max_length=80)
    latitude: float | None = None
    longitude: float | None = None
    is_default: bool = False


class AddressOut(AddressCreate):
    id: UUID

    model_config = {"from_attributes": True}


class CartItemCreate(BaseModel):
    product_id: UUID
    quantity: int = Field(default=1, ge=1, le=99)


class CartItemUpdate(BaseModel):
    quantity: int = Field(ge=1, le=99)


class CartItemOut(BaseModel):
    id: UUID
    product_id: UUID
    seller_id: UUID
    quantity: int
    unit_price_mad: float
    product_name: str
    image_url: str
    seller_name: str
    stock_quantity: int
    is_available: bool


class WishlistItemOut(BaseModel):
    id: UUID
    product_id: UUID
    product_name: str
    image_url: str
    price_mad: float | None
    seller_id: UUID
    seller_name: str


class CheckoutRequest(BaseModel):
    address_id: UUID | None = None
    delivery_name: str = Field(default="", max_length=120)
    delivery_phone: str = Field(default="", max_length=32)
    delivery_address: str = Field(default="", max_length=255)
    delivery_city: str = Field(default="", max_length=80)
    buyer_note: str = Field(default="", max_length=1000)
    payment_method: str = Field(default="cod", pattern="^(cod|card_later)$")
    seller_id: UUID | None = None


class OrderItemOut(BaseModel):
    id: UUID
    product_id: UUID | None
    product_name: str
    quantity: int
    unit_price_mad: float
    total_mad: float
    image_url: str

    model_config = {"from_attributes": True}


class OrderOut(BaseModel):
    id: UUID
    buyer_id: UUID
    seller_id: UUID
    status: OrderStatus
    subtotal_mad: float
    delivery_fee_mad: float
    total_mad: float
    currency: str
    payment_method: str
    payment_status: PaymentStatus
    delivery_name: str
    delivery_phone: str
    delivery_address: str
    delivery_city: str
    buyer_note: str
    seller_note: str
    created_at: datetime
    items: list[OrderItemOut] = []
    seller_name: str = ""

    model_config = {"from_attributes": True}


class GuestCartMigrateRequest(BaseModel):
    items: list[CartItemCreate] = Field(default_factory=list, max_length=50)


def _cart_item_out(item: CartItem, product: Product, seller: SellerProfile) -> CartItemOut:
    return CartItemOut(
        id=item.id,
        product_id=product.id,
        seller_id=seller.id,
        quantity=item.quantity,
        unit_price_mad=item.unit_price_mad,
        product_name=product.name,
        image_url=product.image_url,
        seller_name=seller.business_name,
        stock_quantity=product.stock_quantity,
        is_available=product.is_available and not product.is_hidden,
    )


@router.get("/buyer/addresses", response_model=list[AddressOut])
async def list_addresses(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[BuyerAddress]:
    result = await session.execute(
        select(BuyerAddress).where(BuyerAddress.user_id == user.id).order_by(BuyerAddress.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("/buyer/addresses", response_model=AddressOut, status_code=status.HTTP_201_CREATED)
async def create_address(
    payload: AddressCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> BuyerAddress:
    if payload.is_default:
        existing = await session.execute(select(BuyerAddress).where(BuyerAddress.user_id == user.id))
        for address in existing.scalars().all():
            address.is_default = False

    address = BuyerAddress(id=uuid4(), user_id=user.id, **payload.model_dump())
    session.add(address)
    await session.commit()
    await session.refresh(address)
    return address


@router.delete("/buyer/addresses/{address_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_address(
    address_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    address = await session.get(BuyerAddress, address_id)
    if address is None or address.user_id != user.id:
        raise HTTPException(status_code=404, detail="Address not found")
    await session.delete(address)
    await session.commit()


@router.get("/cart", response_model=list[CartItemOut])
async def get_cart(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[CartItemOut]:
    result = await session.execute(
        select(CartItem, Product, SellerProfile)
        .join(Product, CartItem.product_id == Product.id)
        .join(SellerProfile, CartItem.seller_id == SellerProfile.id)
        .where(CartItem.user_id == user.id)
        .order_by(CartItem.updated_at.desc())
    )
    return [_cart_item_out(item, product, seller) for item, product, seller in result.all()]


@router.post("/cart/items", response_model=CartItemOut, status_code=status.HTTP_201_CREATED)
async def add_cart_item(
    payload: CartItemCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CartItemOut:
    product = await session.get(Product, payload.product_id)
    if product is None or not product.is_available or product.is_hidden:
        raise HTTPException(status_code=404, detail="Product not available")
    if product.price_mad is None:
        raise HTTPException(status_code=400, detail="Product has no price")
    if payload.quantity > product.stock_quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock")

    seller = await session.get(SellerProfile, product.seller_id)
    if seller is None or not seller.is_active:
        raise HTTPException(status_code=404, detail="Seller not available")

    existing = await session.execute(
        select(CartItem).where(CartItem.user_id == user.id, CartItem.product_id == product.id)
    )
    item = existing.scalar_one_or_none()
    if item:
        item.quantity = min(item.quantity + payload.quantity, product.stock_quantity)
        item.unit_price_mad = float(product.price_mad)
    else:
        item = CartItem(
            id=uuid4(),
            user_id=user.id,
            product_id=product.id,
            seller_id=product.seller_id,
            quantity=payload.quantity,
            unit_price_mad=float(product.price_mad),
        )
        session.add(item)

    await session.commit()
    await session.refresh(item)
    return _cart_item_out(item, product, seller)


@router.patch("/cart/items/{item_id}", response_model=CartItemOut)
async def update_cart_item(
    item_id: UUID,
    payload: CartItemUpdate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CartItemOut:
    item = await session.get(CartItem, item_id)
    if item is None or item.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cart item not found")
    product = await session.get(Product, item.product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    if payload.quantity > product.stock_quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock")
    item.quantity = payload.quantity
    await session.commit()
    seller = await session.get(SellerProfile, item.seller_id)
    assert seller is not None
    return _cart_item_out(item, product, seller)


@router.delete("/cart/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_cart_item(
    item_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    item = await session.get(CartItem, item_id)
    if item is None or item.user_id != user.id:
        raise HTTPException(status_code=404, detail="Cart item not found")
    await session.delete(item)
    await session.commit()


@router.post("/cart/migrate-guest", response_model=list[CartItemOut])
async def migrate_guest_cart(
    payload: GuestCartMigrateRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[CartItemOut]:
    for entry in payload.items:
        product = await session.get(Product, entry.product_id)
        if product is None or not product.is_available or product.price_mad is None:
            continue
        existing = await session.execute(
            select(CartItem).where(CartItem.user_id == user.id, CartItem.product_id == product.id)
        )
        item = existing.scalar_one_or_none()
        qty = min(entry.quantity, product.stock_quantity)
        if qty < 1:
            continue
        if item:
            item.quantity = min(item.quantity + qty, product.stock_quantity)
            item.unit_price_mad = float(product.price_mad)
        else:
            session.add(
                CartItem(
                    id=uuid4(),
                    user_id=user.id,
                    product_id=product.id,
                    seller_id=product.seller_id,
                    quantity=qty,
                    unit_price_mad=float(product.price_mad),
                )
            )
    await session.commit()
    return await get_cart(user, session)


@router.get("/wishlist", response_model=list[WishlistItemOut])
async def get_wishlist(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[WishlistItemOut]:
    result = await session.execute(
        select(WishlistItem, Product, SellerProfile)
        .join(Product, WishlistItem.product_id == Product.id)
        .join(SellerProfile, Product.seller_id == SellerProfile.id)
        .where(WishlistItem.user_id == user.id)
        .order_by(WishlistItem.created_at.desc())
    )
    return [
        WishlistItemOut(
            id=item.id,
            product_id=product.id,
            product_name=product.name,
            image_url=product.image_url,
            price_mad=product.price_mad,
            seller_id=seller.id,
            seller_name=seller.business_name,
        )
        for item, product, seller in result.all()
    ]


@router.post("/wishlist/products/{product_id}", response_model=WishlistItemOut, status_code=status.HTTP_201_CREATED)
async def add_wishlist(
    product_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> WishlistItemOut:
    product = await session.get(Product, product_id)
    if product is None or product.is_hidden:
        raise HTTPException(status_code=404, detail="Product not found")
    existing = await session.execute(
        select(WishlistItem).where(WishlistItem.user_id == user.id, WishlistItem.product_id == product_id)
    )
    item = existing.scalar_one_or_none()
    if item is None:
        item = WishlistItem(id=uuid4(), user_id=user.id, product_id=product_id)
        session.add(item)
        await session.commit()
        await session.refresh(item)
    seller = await session.get(SellerProfile, product.seller_id)
    assert seller is not None
    return WishlistItemOut(
        id=item.id,
        product_id=product.id,
        product_name=product.name,
        image_url=product.image_url,
        price_mad=product.price_mad,
        seller_id=seller.id,
        seller_name=seller.business_name,
    )


@router.delete("/wishlist/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_wishlist(
    product_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(WishlistItem).where(WishlistItem.user_id == user.id, WishlistItem.product_id == product_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Wishlist item not found")
    await session.delete(item)
    await session.commit()


@router.post("/checkout", response_model=list[OrderOut], status_code=status.HTTP_201_CREATED)
@limiter.limit("20/minute")
async def checkout(
    request: Request,
    payload: CheckoutRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[OrderOut]:
    delivery_name = payload.delivery_name.strip()
    delivery_phone = payload.delivery_phone.strip()
    delivery_address = payload.delivery_address.strip()
    delivery_city = payload.delivery_city.strip()

    if payload.address_id:
        address = await session.get(BuyerAddress, payload.address_id)
        if address is None or address.user_id != user.id:
            raise HTTPException(status_code=404, detail="Address not found")
        delivery_name = address.recipient_name
        delivery_phone = address.phone
        delivery_address = address.address_line1
        delivery_city = address.city

    if len(delivery_name) < 2 or len(delivery_phone) < 6 or len(delivery_address) < 5 or len(delivery_city) < 2:
        raise HTTPException(status_code=400, detail="Delivery details are required")

    cart_q = (
        select(CartItem, Product, SellerProfile)
        .join(Product, CartItem.product_id == Product.id)
        .join(SellerProfile, CartItem.seller_id == SellerProfile.id)
        .where(CartItem.user_id == user.id)
    )
    if payload.seller_id:
        cart_q = cart_q.where(CartItem.seller_id == payload.seller_id)

    rows = list((await session.execute(cart_q)).all())
    if not rows:
        raise HTTPException(status_code=400, detail="Cart is empty")

    by_seller: dict[UUID, list[tuple[CartItem, Product, SellerProfile]]] = {}
    for item, product, seller in rows:
        if not product.is_available or product.is_hidden or product.price_mad is None:
            raise HTTPException(status_code=400, detail=f"Product unavailable: {product.name}")
        if item.quantity > product.stock_quantity:
            raise HTTPException(status_code=400, detail=f"Insufficient stock for {product.name}")
        by_seller.setdefault(seller.id, []).append((item, product, seller))

    created_orders: list[Order] = []
    for seller_id, group in by_seller.items():
        seller = group[0][2]
        subtotal = sum(item.quantity * float(product.price_mad or 0) for item, product, _ in group)
        delivery_fee = 0.0
        order = Order(
            id=uuid4(),
            buyer_id=user.id,
            seller_id=seller_id,
            status=OrderStatus.PENDING,
            subtotal_mad=subtotal,
            delivery_fee_mad=delivery_fee,
            total_mad=subtotal + delivery_fee,
            payment_method=payload.payment_method,
            payment_status=PaymentStatus.COD if payload.payment_method == "cod" else PaymentStatus.PENDING,
            delivery_name=delivery_name,
            delivery_phone=delivery_phone,
            delivery_address=delivery_address,
            delivery_city=delivery_city,
            buyer_note=payload.buyer_note.strip(),
        )
        session.add(order)
        await session.flush()

        for item, product, _ in group:
            session.add(
                OrderItem(
                    id=uuid4(),
                    order_id=order.id,
                    product_id=product.id,
                    product_name=product.name,
                    quantity=item.quantity,
                    unit_price_mad=float(product.price_mad or 0),
                    total_mad=item.quantity * float(product.price_mad or 0),
                    image_url=product.image_url,
                )
            )
            product.stock_quantity = max(0, product.stock_quantity - item.quantity)
            if product.stock_quantity == 0:
                product.is_available = False
            await session.delete(item)

        seller.order_count = int(seller.order_count or 0) + 1
        await notify_user(
            session,
            user_id=seller.user_id,
            title="New order received",
            body=f"Order from {user.display_name or user.email} · {order.total_mad:.0f} MAD",
            kind="order",
            data={"order_id": str(order.id)},
        )
        created_orders.append(order)

    await session.commit()

    outs: list[OrderOut] = []
    for order in created_orders:
        detail = await session.execute(
            select(Order).options(selectinload(Order.items)).where(Order.id == order.id)
        )
        loaded = detail.scalar_one()
        seller = await session.get(SellerProfile, loaded.seller_id)
        outs.append(
            OrderOut(
                id=loaded.id,
                buyer_id=loaded.buyer_id,
                seller_id=loaded.seller_id,
                status=loaded.status,
                subtotal_mad=loaded.subtotal_mad,
                delivery_fee_mad=loaded.delivery_fee_mad,
                total_mad=loaded.total_mad,
                currency=loaded.currency,
                payment_method=loaded.payment_method,
                payment_status=loaded.payment_status,
                delivery_name=loaded.delivery_name,
                delivery_phone=loaded.delivery_phone,
                delivery_address=loaded.delivery_address,
                delivery_city=loaded.delivery_city,
                buyer_note=loaded.buyer_note,
                seller_note=loaded.seller_note,
                created_at=loaded.created_at,
                items=list(loaded.items),
                seller_name=seller.business_name if seller else "",
            )
        )
    return outs


@router.get("/orders", response_model=list[OrderOut])
async def list_buyer_orders(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[OrderOut]:
    result = await session.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.buyer_id == user.id)
        .order_by(Order.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    orders = list(result.scalars().unique().all())
    outs: list[OrderOut] = []
    for order in orders:
        seller = await session.get(SellerProfile, order.seller_id)
        outs.append(
            OrderOut(
                id=order.id,
                buyer_id=order.buyer_id,
                seller_id=order.seller_id,
                status=order.status,
                subtotal_mad=order.subtotal_mad,
                delivery_fee_mad=order.delivery_fee_mad,
                total_mad=order.total_mad,
                currency=order.currency,
                payment_method=order.payment_method,
                payment_status=order.payment_status,
                delivery_name=order.delivery_name,
                delivery_phone=order.delivery_phone,
                delivery_address=order.delivery_address,
                delivery_city=order.delivery_city,
                buyer_note=order.buyer_note,
                seller_note=order.seller_note,
                created_at=order.created_at,
                items=list(order.items),
                seller_name=seller.business_name if seller else "",
            )
        )
    return outs


@router.get("/orders/{order_id}", response_model=OrderOut)
async def get_order(
    order_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> OrderOut:
    result = await session.execute(
        select(Order).options(selectinload(Order.items)).where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=404, detail="Order not found")

    seller = await session.get(SellerProfile, order.seller_id)
    is_seller_owner = seller is not None and seller.user_id == user.id
    if order.buyer_id != user.id and not is_seller_owner:
        raise HTTPException(status_code=404, detail="Order not found")

    return OrderOut(
        id=order.id,
        buyer_id=order.buyer_id,
        seller_id=order.seller_id,
        status=order.status,
        subtotal_mad=order.subtotal_mad,
        delivery_fee_mad=order.delivery_fee_mad,
        total_mad=order.total_mad,
        currency=order.currency,
        payment_method=order.payment_method,
        payment_status=order.payment_status,
        delivery_name=order.delivery_name,
        delivery_phone=order.delivery_phone,
        delivery_address=order.delivery_address,
        delivery_city=order.delivery_city,
        buyer_note=order.buyer_note,
        seller_note=order.seller_note,
        created_at=order.created_at,
        items=list(order.items),
        seller_name=seller.business_name if seller else "",
    )


@router.post("/orders/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(
    order_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> OrderOut:
    result = await session.execute(
        select(Order).options(selectinload(Order.items)).where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if order is None or order.buyer_id != user.id:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status not in {OrderStatus.PENDING, OrderStatus.ACCEPTED}:
        raise HTTPException(status_code=400, detail="Order cannot be cancelled")

    order.status = OrderStatus.CANCELLED
    order.cancelled_at = datetime.now(UTC)
    for item in order.items:
        if item.product_id:
            product = await session.get(Product, item.product_id)
            if product:
                product.stock_quantity += item.quantity
                product.is_available = True

    seller = await session.get(SellerProfile, order.seller_id)
    if seller:
        await notify_user(
            session,
            user_id=seller.user_id,
            title="Order cancelled",
            body=f"Buyer cancelled order {str(order.id)[:8]}",
            kind="order",
            data={"order_id": str(order.id)},
        )
    await session.commit()
    return await get_order(order_id, user, session)
