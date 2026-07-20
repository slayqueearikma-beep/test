"""Pivot to discovery marketplace: drop ecommerce, add discovery features.

Revision ID: 007
Revises: 006
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "007"
down_revision: Union[str, None] = "006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop ecommerce tables first (FKs).
    for table in (
        "order_items",
        "orders",
        "cart_items",
        "buyer_addresses",
        "coupons",
    ):
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")

    # Drop ecommerce enums if present.
    op.execute("DROP TYPE IF EXISTS orderstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS paymentstatus CASCADE")

    # Seller storefront enrichment
    op.add_column("seller_profiles", sa.Column("website_url", sa.String(length=255), server_default="", nullable=False))
    op.add_column("seller_profiles", sa.Column("instagram_url", sa.String(length=255), server_default="", nullable=False))
    op.add_column("seller_profiles", sa.Column("facebook_url", sa.String(length=255), server_default="", nullable=False))
    op.add_column("seller_profiles", sa.Column("tiktok_url", sa.String(length=255), server_default="", nullable=False))
    op.add_column("seller_profiles", sa.Column("whatsapp_number", sa.String(length=32), server_default="", nullable=False))
    op.add_column(
        "seller_profiles",
        sa.Column(
            "payment_methods",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[\"cash\"]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "seller_profiles",
        sa.Column(
            "delivery_methods",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[\"in_store\"]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("service_areas", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("avg_response_minutes", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("inquiry_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("favorite_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("contact_click_count", sa.Integer(), server_default="0", nullable=False),
    )

    # Drop ecommerce seller metrics if present
    op.execute("ALTER TABLE seller_profiles DROP COLUMN IF EXISTS total_sales_mad")
    op.execute("ALTER TABLE seller_profiles DROP COLUMN IF EXISTS order_count")

    # Listing enrichment
    op.add_column(
        "products",
        sa.Column("price_negotiable", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("availability_note", sa.String(length=160), server_default="", nullable=False),
    )
    op.add_column(
        "products",
        sa.Column(
            "accepted_payment_methods",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "products",
        sa.Column(
            "delivery_options",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "products",
        sa.Column("is_featured", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("is_paused", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("media_urls", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("video_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("category_slug", sa.String(length=80), server_default="", nullable=False),
    )
    # Keep stock_quantity as optional availability hint but stop treating as warehouse stock.
    op.execute("ALTER TABLE products DROP COLUMN IF EXISTS sku")

    op.add_column(
        "services",
        sa.Column("price_negotiable", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "services",
        sa.Column("coverage_areas", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
    )
    op.add_column(
        "services",
        sa.Column("is_featured", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )

    # Rename wishlist semantics via new favorites table; keep wishlist_items for compat then drop.
    op.execute("DROP TABLE IF EXISTS wishlist_items CASCADE")

    op.create_table(
        "favorites",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_favorites_user_id", "favorites", ["user_id"])
    op.create_index("ix_favorites_product_id", "favorites", ["product_id"])
    op.create_index("ix_favorites_seller_id", "favorites", ["seller_id"])

    op.create_table(
        "seller_follows",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "seller_id", name="uq_follow_user_seller"),
    )
    op.create_index("ix_seller_follows_user_id", "seller_follows", ["user_id"])

    op.create_table(
        "saved_searches",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("query", sa.String(length=160), server_default="", nullable=False),
        sa.Column("city", sa.String(length=80), server_default="", nullable=False),
        sa.Column("category", sa.String(length=80), server_default="", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_saved_searches_user_id", "saved_searches", ["user_id"])

    op.create_table(
        "recently_viewed",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=True),
        sa.Column("viewed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_recently_viewed_user_id", "recently_viewed", ["user_id"])

    op.create_table(
        "reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("reporter_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=True),
        sa.Column("reason", sa.String(length=80), nullable=False),
        sa.Column("details", sa.Text(), server_default="", nullable=False),
        sa.Column("status", sa.String(length=32), server_default="open", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_reports_status", "reports", ["status"])

    op.create_table(
        "contact_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("channel", sa.String(length=32), nullable=False),  # call|whatsapp|email|message|website
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_contact_events_seller_id", "contact_events", ["seller_id"])


def downgrade() -> None:
    for table in (
        "contact_events",
        "reports",
        "recently_viewed",
        "saved_searches",
        "seller_follows",
        "favorites",
    ):
        op.drop_table(table)

    op.drop_column("products", "is_featured")
    op.drop_column("products", "delivery_options")
    op.drop_column("products", "accepted_payment_methods")
    op.drop_column("products", "availability_note")
    op.drop_column("products", "price_negotiable")

    for col in (
        "contact_click_count",
        "favorite_count",
        "inquiry_count",
        "avg_response_minutes",
        "service_areas",
        "delivery_methods",
        "payment_methods",
        "whatsapp_number",
        "tiktok_url",
        "facebook_url",
        "instagram_url",
        "website_url",
    ):
        op.drop_column("seller_profiles", col)
