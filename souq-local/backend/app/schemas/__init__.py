from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class AccountType(str, Enum):
    BUYER = "buyer"
    SELLER = "seller"


class UserRegister(BaseModel):
    firebase_uid: str
    email: str
    account_type: AccountType
    display_name: str = ""


class UserOut(BaseModel):
    id: UUID
    firebase_uid: str
    email: str
    account_type: AccountType
    display_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


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
    image_url: str = ""


class ProductOut(BaseModel):
    id: UUID
    name: str
    description: str
    price_mad: float | None
    image_url: str
    is_available: bool

    model_config = {"from_attributes": True}


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    price_mad: float | None = None
    image_url: str = ""


class ServiceOut(BaseModel):
    id: UUID
    name: str
    description: str
    price_mad: float | None
    image_url: str
    is_available: bool

    model_config = {"from_attributes": True}


class SellerCreate(BaseModel):
    business_name: str = Field(min_length=2, max_length=160)
    description: str = ""
    address: str = Field(min_length=5, max_length=255)
    city: str = Field(min_length=2, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    phone: str = ""
    cover_image_url: str = ""
    category_ids: list[UUID] = Field(default_factory=list)


class SellerUpdate(BaseModel):
    business_name: str | None = None
    description: str | None = None
    address: str | None = None
    city: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    phone: str | None = None
    cover_image_url: str | None = None
    category_ids: list[UUID] | None = None


class SellerSummary(BaseModel):
    id: UUID
    business_name: str
    description: str
    city: str
    latitude: float
    longitude: float
    cover_image_url: str
    achievement_stars: int
    average_rating: float
    review_count: int
    categories: list[CategoryOut]

    model_config = {"from_attributes": True}


class SellerDetail(SellerSummary):
    address: str
    phone: str
    products: list[ProductOut]
    services: list[ServiceOut]


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
