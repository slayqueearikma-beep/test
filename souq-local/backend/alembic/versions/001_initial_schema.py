"""Initial MarGem schema

Revision ID: 001
Revises:
Create Date: 2026-07-17
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    account_type = postgresql.ENUM("buyer", "seller", name="accounttype", create_type=True)
    account_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("firebase_uid", sa.String(128), unique=True, nullable=False),
        sa.Column("email", sa.String(255), unique=True, nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("account_type", account_type, nullable=False),
        sa.Column("display_name", sa.String(120), server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"])

    op.create_table(
        "categories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.String(64), unique=True, nullable=False),
        sa.Column("name_en", sa.String(80), nullable=False),
        sa.Column("name_fr", sa.String(80), server_default=""),
        sa.Column("name_ar", sa.String(80), server_default=""),
        sa.Column("icon", sa.String(32), server_default="store"),
    )

    op.create_table(
        "seller_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), unique=True),
        sa.Column("business_name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("address", sa.String(255), nullable=False),
        sa.Column("city", sa.String(80), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("phone", sa.String(32), server_default=""),
        sa.Column("cover_image_url", sa.String(512), server_default=""),
        sa.Column("achievement_stars", sa.Integer(), server_default="0"),
        sa.Column("average_rating", sa.Float(), server_default="0"),
        sa.Column("review_count", sa.Integer(), server_default="0"),
        sa.Column("is_active", sa.Boolean(), server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_seller_profiles_city", "seller_profiles", ["city"])

    op.create_table(
        "seller_categories",
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id"), primary_key=True),
        sa.Column("category_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("categories.id"), primary_key=True),
    )

    op.create_table(
        "products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id")),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("price_mad", sa.Float(), nullable=True),
        sa.Column("image_url", sa.String(512), server_default=""),
        sa.Column("is_available", sa.Boolean(), server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "services",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id")),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("price_mad", sa.Float(), nullable=True),
        sa.Column("image_url", sa.String(512), server_default=""),
        sa.Column("is_available", sa.Boolean(), server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "reviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id")),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id")),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("seller_id", "buyer_id", name="uq_review_seller_buyer"),
    )

    op.create_table(
        "warning_zones",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), server_default=""),
        sa.Column("city", sa.String(80), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("radius_meters", sa.Float(), server_default="200"),
        sa.Column("is_active", sa.Boolean(), server_default="true"),
    )


def downgrade() -> None:
    op.drop_table("warning_zones")
    op.drop_table("reviews")
    op.drop_table("services")
    op.drop_table("products")
    op.drop_table("seller_categories")
    op.drop_table("seller_profiles")
    op.drop_table("categories")
    op.drop_table("users")
    sa.Enum(name="accounttype").drop(op.get_bind(), checkfirst=True)
