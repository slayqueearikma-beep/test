from datetime import datetime
from enum import Enum
from urllib.parse import urlparse
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.services.password_policy import validate_password_strength


def _validate_http_url(value: str, *, field_name: str = "url") -> str:
    cleaned = value.strip()
    if not cleaned:
        return ""
    parsed = urlparse(cleaned)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"{field_name} must be an absolute http(s) URL")
    if len(cleaned) > 2048:
        raise ValueError(f"{field_name} is too long")
    return cleaned


def _validate_media_urls(urls: list[str]) -> list[str]:
    if len(urls) > 12:
        raise ValueError("At most 12 media URLs are allowed")
    return [_validate_http_url(u, field_name="media_urls") for u in urls if u and u.strip()]


class AccountType(str, Enum):
    BUYER = "buyer"
    SELLER = "seller"


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    # Optional — defaults to buyer. Sellers unlock storefront later on the same account.
    account_type: AccountType = AccountType.BUYER
    display_name: str = Field(default="", max_length=120)

    @field_validator("password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        validate_password_strength(value)
        return value


class UserRegisterFirebase(BaseModel):
    firebase_uid: str
    email: EmailStr
    account_type: AccountType = AccountType.BUYER
    display_name: str = ""


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    id: UUID
    email: str
    account_type: AccountType
    display_name: str
    phone: str = ""
    email_verified: bool = False
    is_premium: bool = False
    premium_until: datetime | None = None
    role: str = "buyer"
    status: str = "active"
    mfa_enabled: bool = False
    has_seller_profile: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user, *, has_seller_profile: bool = False) -> "UserOut":
        return cls(
            id=user.id,
            email=user.email,
            account_type=user.account_type,
            display_name=user.display_name,
            phone=getattr(user, "phone", "") or "",
            email_verified=getattr(user, "email_verified_at", None) is not None,
            is_premium=bool(getattr(user, "is_premium", False)),
            premium_until=getattr(user, "premium_until", None),
            role=getattr(user, "role", None).value if getattr(user, "role", None) else "buyer",
            status=getattr(user, "status", None).value if getattr(user, "status", None) else "active",
            mfa_enabled=bool(getattr(user, "mfa_enabled", False)),
            has_seller_profile=has_seller_profile,
            created_at=user.created_at,
        )


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)
    confirmation: str = Field(description="Must equal DELETE")

    @field_validator("confirmation")
    @classmethod
    def must_confirm(cls, value: str) -> str:
        if value.strip() != "DELETE":
            raise ValueError("confirmation must be DELETE")
        return value


class CategoryOut(BaseModel):
    id: UUID
    slug: str
    name_en: str
    name_fr: str
    name_ar: str
    icon: str

    model_config = {"from_attributes": True}


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    price_mad: float | None = None
    price_negotiable: bool = False
    availability_note: str = Field(default="", max_length=160)
    accepted_payment_methods: list[str] = Field(default_factory=list)
    delivery_options: list[str] = Field(default_factory=list)
    image_url: str = ""
    media_urls: list[str] = Field(default_factory=list)
    video_url: str = Field(default="", max_length=512)
    category_slug: str = Field(default="", max_length=80)
    stock_quantity: int = Field(default=1, ge=0, le=1_000_000)
    is_featured: bool = False

    @field_validator("image_url", "video_url")
    @classmethod
    def validate_optional_urls(cls, value: str) -> str:
        return _validate_http_url(value)

    @field_validator("media_urls")
    @classmethod
    def validate_media(cls, value: list[str]) -> list[str]:
        return _validate_media_urls(value)


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = None
    price_mad: float | None = None
    price_negotiable: bool | None = None
    availability_note: str | None = Field(default=None, max_length=160)
    accepted_payment_methods: list[str] | None = None
    delivery_options: list[str] | None = None
    image_url: str | None = None
    media_urls: list[str] | None = None
    video_url: str | None = Field(default=None, max_length=512)
    category_slug: str | None = Field(default=None, max_length=80)
    is_available: bool | None = None
    stock_quantity: int | None = Field(default=None, ge=0, le=1_000_000)
    is_hidden: bool | None = None
    is_featured: bool | None = None
    is_paused: bool | None = None

    @field_validator("image_url", "video_url")
    @classmethod
    def validate_optional_urls(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_http_url(value)

    @field_validator("media_urls")
    @classmethod
    def validate_media(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        return _validate_media_urls(value)


class ProductOut(BaseModel):
    id: UUID
    name: str
    description: str
    price_mad: float | None
    price_negotiable: bool = False
    availability_note: str = ""
    accepted_payment_methods: list = Field(default_factory=list)
    delivery_options: list = Field(default_factory=list)
    image_url: str
    media_urls: list = Field(default_factory=list)
    video_url: str = ""
    category_slug: str = ""
    is_available: bool
    stock_quantity: int = 1
    is_hidden: bool = False
    is_featured: bool = False
    is_paused: bool = False

    model_config = {"from_attributes": True}


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    price_mad: float | None = None
    price_negotiable: bool = False
    coverage_areas: list[str] = Field(default_factory=list)
    image_url: str = ""
    is_featured: bool = False


class ServiceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = None
    price_mad: float | None = None
    price_negotiable: bool | None = None
    coverage_areas: list[str] | None = None
    image_url: str | None = None
    is_available: bool | None = None
    is_featured: bool | None = None


class ServiceOut(BaseModel):
    id: UUID
    name: str
    description: str
    price_mad: float | None
    price_negotiable: bool = False
    coverage_areas: list = Field(default_factory=list)
    image_url: str
    is_available: bool
    is_featured: bool = False

    model_config = {"from_attributes": True}


class OpeningHours(BaseModel):
    days: dict[str, bool] = Field(default_factory=dict)
    open: str = Field(default="09:00", max_length=5)
    close: str = Field(default="21:00", max_length=5)

    @field_validator("open", "close")
    @classmethod
    def validate_time(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) != 5 or cleaned[2] != ":":
            raise ValueError("Time must be HH:MM")
        hour_s, minute_s = cleaned.split(":")
        if not (hour_s.isdigit() and minute_s.isdigit()):
            raise ValueError("Time must be HH:MM")
        hour, minute = int(hour_s), int(minute_s)
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            raise ValueError("Time must be a valid clock time")
        return f"{hour:02d}:{minute:02d}"


class SellerCreate(BaseModel):
    business_name: str = Field(min_length=2, max_length=160)
    description: str = ""
    address: str = Field(min_length=5, max_length=255)
    city: str = Field(min_length=2, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    phone: str = ""
    cover_image_url: str = ""
    logo_image_url: str = ""
    opening_hours: OpeningHours | None = None
    website_url: str = Field(default="", max_length=255)
    instagram_url: str = Field(default="", max_length=255)
    facebook_url: str = Field(default="", max_length=255)
    tiktok_url: str = Field(default="", max_length=255)
    whatsapp_number: str = Field(default="", max_length=32)
    payment_methods: list[str] = Field(default_factory=lambda: ["cash"])
    delivery_methods: list[str] = Field(default_factory=lambda: ["in_store"])
    service_areas: list[str] = Field(default_factory=list)
    category_ids: list[UUID] = Field(default_factory=list)


class SellerUpdate(BaseModel):
    business_name: str | None = Field(default=None, min_length=2, max_length=160)
    description: str | None = None
    address: str | None = Field(default=None, min_length=5, max_length=255)
    city: str | None = Field(default=None, min_length=2, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    phone: str | None = None
    cover_image_url: str | None = None
    logo_image_url: str | None = None
    opening_hours: OpeningHours | None = None
    website_url: str | None = Field(default=None, max_length=255)
    instagram_url: str | None = Field(default=None, max_length=255)
    facebook_url: str | None = Field(default=None, max_length=255)
    tiktok_url: str | None = Field(default=None, max_length=255)
    whatsapp_number: str | None = Field(default=None, max_length=32)
    payment_methods: list[str] | None = None
    delivery_methods: list[str] | None = None
    service_areas: list[str] | None = None
    category_ids: list[UUID] | None = None
    is_active: bool | None = None


class SellerSummary(BaseModel):
    id: UUID
    business_name: str
    description: str
    city: str
    latitude: float
    longitude: float
    cover_image_url: str
    logo_image_url: str = ""
    achievement_stars: int
    average_rating: float
    review_count: int
    is_premium: bool = False
    verification_status: str = "unverified"
    avg_response_minutes: int = 0
    categories: list[CategoryOut]

    model_config = {"from_attributes": True}

    @field_validator("verification_status", mode="before")
    @classmethod
    def coerce_verification(cls, value):
        return value.value if hasattr(value, "value") else value


class SellerDetail(SellerSummary):
    address: str
    phone: str
    opening_hours: dict = Field(default_factory=dict)
    website_url: str = ""
    instagram_url: str = ""
    facebook_url: str = ""
    tiktok_url: str = ""
    whatsapp_number: str = ""
    payment_methods: list = Field(default_factory=list)
    delivery_methods: list = Field(default_factory=list)
    service_areas: list = Field(default_factory=list)
    profile_view_count: int = 0
    inquiry_count: int = 0
    favorite_count: int = 0
    contact_click_count: int = 0
    products: list[ProductOut]
    services: list[ServiceOut]


class SellerDashboardStats(BaseModel):
    seller_id: UUID
    business_name: str
    profile_view_count: int
    product_count: int
    available_product_count: int
    service_count: int
    review_count: int
    average_rating: float
    achievement_stars: int
    recent_review_count: int
    inquiry_count: int = 0
    favorite_count: int = 0
    contact_click_count: int = 0
    avg_response_minutes: int = 0
    is_premium: bool = False
    verification_status: str = "unverified"
    is_active: bool


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        validate_password_strength(value)
        return value


class MapPin(BaseModel):
    id: UUID
    business_name: str
    latitude: float
    longitude: float
    achievement_stars: int
    average_rating: float
    category_slugs: list[str]


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=2000)

    @field_validator("rating")
    @classmethod
    def validate_rating(cls, value: int) -> int:
        if not 1 <= value <= 5:
            raise ValueError("Rating must be between 1 and 5")
        return value


class ReviewOut(BaseModel):
    id: UUID
    rating: int
    comment: str
    buyer_display_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class WarningZoneOut(BaseModel):
    id: UUID
    name: str
    description: str
    city: str
    latitude: float
    longitude: float
    radius_meters: float

    model_config = {"from_attributes": True}


class PresignRequest(BaseModel):
    filename: str
    content_type: str = "image/jpeg"


class PresignResponse(BaseModel):
    upload_url: str
    public_url: str
