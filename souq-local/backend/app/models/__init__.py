import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class AccountType(str, enum.Enum):
    BUYER = "buyer"
    SELLER = "seller"


# Persist enum *values* ("buyer"/"seller") to match Postgres accounttype.
account_type_enum = Enum(
    AccountType,
    name="accounttype",
    values_callable=lambda enum_cls: [member.value for member in enum_cls],
    create_constraint=False,
    native_enum=True,
    validate_strings=True,
)


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_type: Mapped[AccountType] = mapped_column(account_type_enum, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller_profile: Mapped["SellerProfile | None"] = relationship(back_populates="user", uselist=False)
    reviews_written: Mapped[list["Review"]] = relationship(back_populates="buyer")
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name_en: Mapped[str] = mapped_column(String(80))
    name_fr: Mapped[str] = mapped_column(String(80), default="")
    name_ar: Mapped[str] = mapped_column(String(80), default="")
    icon: Mapped[str] = mapped_column(String(32), default="store")

    sellers: Mapped[list["SellerProfile"]] = relationship(
        secondary="seller_categories", back_populates="categories"
    )


class SellerCategory(Base):
    __tablename__ = "seller_categories"

    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), primary_key=True)
    category_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("categories.id"), primary_key=True)


class SellerProfile(Base):
    __tablename__ = "seller_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), unique=True)
    business_name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    address: Mapped[str] = mapped_column(String(255))
    city: Mapped[str] = mapped_column(String(80), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    phone: Mapped[str] = mapped_column(String(32), default="")
    cover_image_url: Mapped[str] = mapped_column(String(512), default="")
    achievement_stars: Mapped[int] = mapped_column(Integer, default=0)
    average_rating: Mapped[float] = mapped_column(Float, default=0.0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="seller_profile")
    categories: Mapped[list[Category]] = relationship(
        secondary="seller_categories", back_populates="sellers"
    )
    products: Mapped[list["Product"]] = relationship(back_populates="seller", cascade="all, delete-orphan")
    services: Mapped[list["Service"]] = relationship(back_populates="seller", cascade="all, delete-orphan")
    reviews: Mapped[list["Review"]] = relationship(back_populates="seller", cascade="all, delete-orphan")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float | None] = mapped_column(Float, nullable=True)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller: Mapped[SellerProfile] = relationship(back_populates="products")


class Service(Base):
    __tablename__ = "services"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float | None] = mapped_column(Float, nullable=True)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller: Mapped[SellerProfile] = relationship(back_populates="services")


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("seller_id", "buyer_id", name="uq_review_seller_buyer"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    buyer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    seller: Mapped[SellerProfile] = relationship(back_populates="reviews")
    buyer: Mapped[User] = relationship(back_populates="reviews_written")


class WarningZone(Base):
    __tablename__ = "warning_zones"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    city: Mapped[str] = mapped_column(String(80), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    radius_meters: Mapped[float] = mapped_column(Float, default=200.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
