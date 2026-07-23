import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class AccountType(str, enum.Enum):
    BUYER = "buyer"
    SELLER = "seller"


class UserStatus(str, enum.Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    DELETED = "deleted"


class UserRole(str, enum.Enum):
    BUYER = "buyer"
    SELLER = "seller"
    ADMIN = "admin"
    SUPPORT = "support"


class SubscriptionStatus(str, enum.Enum):
    ACTIVE = "active"
    TRIALING = "trialing"
    PAST_DUE = "past_due"
    CANCELED = "canceled"
    EXPIRED = "expired"


class VerificationStatus(str, enum.Enum):
    UNVERIFIED = "unverified"
    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"


def _enum(enum_cls: type[enum.Enum], name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        create_constraint=False,
        native_enum=True,
        validate_strings=True,
    )


account_type_enum = _enum(AccountType, "accounttype")
user_status_enum = _enum(UserStatus, "userstatus")
user_role_enum = _enum(UserRole, "userrole")
subscription_status_enum = _enum(SubscriptionStatus, "subscriptionstatus")
verification_status_enum = _enum(VerificationStatus, "verificationstatus")


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_type: Mapped[AccountType] = mapped_column(account_type_enum, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), default="")
    phone: Mapped[str] = mapped_column(String(32), default="")
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[UserStatus] = mapped_column(user_status_enum, default=UserStatus.ACTIVE)
    role: Mapped[UserRole] = mapped_column(user_role_enum, default=UserRole.BUYER)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    premium_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller_profile: Mapped["SellerProfile | None"] = relationship(back_populates="user", uselist=False)
    reviews_written: Mapped[list["Review"]] = relationship(back_populates="buyer")
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    favorites: Mapped[list["Favorite"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    device_name: Mapped[str] = mapped_column(String(120), default="")
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(255), default="")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class AuthToken(Base):
    __tablename__ = "auth_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    purpose: Mapped[str] = mapped_column(String(32), index=True)  # email_verify | password_reset
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MfaFactor(Base):
    __tablename__ = "mfa_factors"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    factor_type: Mapped[str] = mapped_column(String(32), default="totp")
    secret_encrypted: Mapped[str] = mapped_column(String(512))
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    disabled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


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
    logo_image_url: Mapped[str] = mapped_column(String(512), default="")
    opening_hours: Mapped[dict] = mapped_column(JSONB, default=dict)
    website_url: Mapped[str] = mapped_column(String(255), default="")
    instagram_url: Mapped[str] = mapped_column(String(255), default="")
    facebook_url: Mapped[str] = mapped_column(String(255), default="")
    tiktok_url: Mapped[str] = mapped_column(String(255), default="")
    whatsapp_number: Mapped[str] = mapped_column(String(32), default="")
    payment_methods: Mapped[list] = mapped_column(JSONB, default=lambda: ["cash"])
    delivery_methods: Mapped[list] = mapped_column(JSONB, default=lambda: ["in_store"])
    service_areas: Mapped[list] = mapped_column(JSONB, default=list)
    avg_response_minutes: Mapped[int] = mapped_column(Integer, default=0)
    inquiry_count: Mapped[int] = mapped_column(Integer, default=0)
    favorite_count: Mapped[int] = mapped_column(Integer, default=0)
    contact_click_count: Mapped[int] = mapped_column(Integer, default=0)
    profile_view_count: Mapped[int] = mapped_column(Integer, default=0)
    achievement_stars: Mapped[int] = mapped_column(Integer, default=0)
    average_rating: Mapped[float] = mapped_column(Float, default=0.0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    verification_status: Mapped[VerificationStatus] = mapped_column(
        verification_status_enum, default=VerificationStatus.UNVERIFIED
    )
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
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
    price_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    price_negotiable: Mapped[bool] = mapped_column(Boolean, default=False)
    availability_note: Mapped[str] = mapped_column(String(160), default="")
    accepted_payment_methods: Mapped[list] = mapped_column(JSONB, default=list)
    delivery_options: Mapped[list] = mapped_column(JSONB, default=list)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    media_urls: Mapped[list] = mapped_column(JSONB, default=list)
    video_url: Mapped[str] = mapped_column(String(512), default="")
    category_slug: Mapped[str] = mapped_column(String(80), default="")
    stock_quantity: Mapped[int] = mapped_column(Integer, default=1)  # availability hint, not warehouse stock
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    is_paused: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller: Mapped[SellerProfile] = relationship(back_populates="products")


class Service(Base):
    __tablename__ = "services"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    price_negotiable: Mapped[bool] = mapped_column(Boolean, default=False)
    coverage_areas: Mapped[list] = mapped_column(JSONB, default=list)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
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


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (
        # Partial uniqueness is enforced in migration 008; keep ORM indexes aligned.
        Index("ix_favorites_user_product", "user_id", "product_id"),
        Index("ix_favorites_user_seller", "user_id", "seller_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=True, index=True
    )
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="favorites")
    product: Mapped["Product | None"] = relationship()
    seller: Mapped["SellerProfile | None"] = relationship()


class SellerFollow(Base):
    __tablename__ = "seller_follows"
    __table_args__ = (UniqueConstraint("user_id", "seller_id", name="uq_follow_user_seller"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SavedSearch(Base):
    __tablename__ = "saved_searches"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    query: Mapped[str] = mapped_column(String(160), default="")
    city: Mapped[str] = mapped_column(String(80), default="")
    category: Mapped[str] = mapped_column(String(80), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RecentlyViewed(Base):
    __tablename__ = "recently_viewed"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=True)
    viewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reporter_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=True)
    reason: Mapped[str] = mapped_column(String(80))
    details: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ContactEvent(Base):
    __tablename__ = "contact_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    channel: Mapped[str] = mapped_column(String(32))  # call|whatsapp|email|message|website|sms
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        UniqueConstraint("participant_a_id", "participant_b_id", name="uq_conversation_participants"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Canonical unordered pair: participant_a_id < participant_b_id (both users).
    participant_a_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    participant_b_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    # Optional storefront that was contacted (inquiry analytics); null for pure user↔user.
    context_seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True, index=True
    )
    last_message_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    messages: Mapped[list["Message"]] = relationship(back_populates="conversation", cascade="all, delete-orphan")

    def other_participant(self, user_id: uuid.UUID) -> uuid.UUID:
        if self.participant_a_id == user_id:
            return self.participant_b_id
        if self.participant_b_id == user_id:
            return self.participant_a_id
        raise ValueError("user is not a participant")

    def involves(self, user_id: uuid.UUID) -> bool:
        return user_id in {self.participant_a_id, self.participant_b_id}


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conversations.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation: Mapped[Conversation] = relationship(back_populates="messages")


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(Text, default="")
    kind: Mapped[str] = mapped_column(String(40), default="general")
    data: Mapped[dict] = mapped_column(JSONB, default=dict)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="notifications")


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(40), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    billing_period_days: Mapped[int] = mapped_column(Integer, default=30)
    features: Mapped[list] = mapped_column(JSONB, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("subscription_plans.id"))
    status: Mapped[SubscriptionStatus] = mapped_column(
        subscription_status_enum, default=SubscriptionStatus.ACTIVE
    )
    current_period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    current_period_end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    provider: Mapped[str] = mapped_column(String(40), default="manual")
    provider_reference: Mapped[str] = mapped_column(String(120), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    plan: Mapped[SubscriptionPlan] = relationship()


class AdminAuditLog(Base):
    __tablename__ = "admin_audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(80))
    target_type: Mapped[str] = mapped_column(String(40), default="")
    target_id: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
