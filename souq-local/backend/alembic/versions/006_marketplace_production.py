"""Marketplace production foundation: identity, commerce, messaging, premium, admin.

Revision ID: 006
Revises: 005
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

userstatus = postgresql.ENUM("active", "suspended", "deleted", name="userstatus", create_type=False)
userrole = postgresql.ENUM("buyer", "seller", "admin", "support", name="userrole", create_type=False)
orderstatus = postgresql.ENUM(
    "pending",
    "accepted",
    "rejected",
    "ready",
    "completed",
    "cancelled",
    name="orderstatus",
    create_type=False,
)
paymentstatus = postgresql.ENUM(
    "pending", "paid", "failed", "refunded", "cod", name="paymentstatus", create_type=False
)
substatus = postgresql.ENUM(
    "active", "trialing", "past_due", "canceled", "expired", name="subscriptionstatus", create_type=False
)
verify_status = postgresql.ENUM(
    "unverified", "pending", "verified", "rejected", name="verificationstatus", create_type=False
)


def upgrade() -> None:
    bind = op.get_bind()
    for enum_type in (userstatus, userrole, orderstatus, paymentstatus, substatus, verify_status):
        enum_type.create(bind, checkfirst=True)

    op.add_column("users", sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("phone", sa.String(length=32), server_default="", nullable=False))
    op.add_column(
        "users",
        sa.Column("status", userstatus, server_default="active", nullable=False),
    )
    op.add_column(
        "users",
        sa.Column("role", userrole, server_default="buyer", nullable=False),
    )
    op.add_column("users", sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        "users",
        sa.Column("is_premium", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "users",
        sa.Column("premium_until", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("mfa_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )

    op.add_column("refresh_tokens", sa.Column("device_name", sa.String(length=120), server_default="", nullable=False))
    op.add_column("refresh_tokens", sa.Column("ip_address", sa.String(length=64), server_default="", nullable=False))
    op.add_column("refresh_tokens", sa.Column("user_agent", sa.String(length=255), server_default="", nullable=False))
    op.add_column("refresh_tokens", sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True))

    op.add_column(
        "products",
        sa.Column("stock_quantity", sa.Integer(), server_default="100", nullable=False),
    )
    op.add_column("products", sa.Column("sku", sa.String(length=64), server_default="", nullable=False))
    op.add_column(
        "products",
        sa.Column("is_hidden", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )

    op.add_column(
        "seller_profiles",
        sa.Column("verification_status", verify_status, server_default="unverified", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("is_premium", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("total_sales_mad", sa.Float(), server_default="0", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("order_count", sa.Integer(), server_default="0", nullable=False),
    )

    op.create_table(
        "auth_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("purpose", sa.String(length=32), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_auth_tokens_user_id", "auth_tokens", ["user_id"])
    op.create_index("ix_auth_tokens_purpose", "auth_tokens", ["purpose"])

    op.create_table(
        "mfa_factors",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("factor_type", sa.String(length=32), nullable=False),
        sa.Column("secret_encrypted", sa.String(length=512), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("disabled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_mfa_factors_user_id", "mfa_factors", ["user_id"])

    op.create_table(
        "buyer_addresses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.String(length=80), server_default="Home", nullable=False),
        sa.Column("recipient_name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=False),
        sa.Column("address_line1", sa.String(length=255), nullable=False),
        sa.Column("city", sa.String(length=80), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("is_default", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_buyer_addresses_user_id", "buyer_addresses", ["user_id"])

    op.create_table(
        "cart_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price_mad", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "product_id", name="uq_cart_user_product"),
    )
    op.create_index("ix_cart_items_user_id", "cart_items", ["user_id"])

    op.create_table(
        "wishlist_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("user_id", "product_id", name="uq_wishlist_user_product"),
    )
    op.create_index("ix_wishlist_items_user_id", "wishlist_items", ["user_id"])

    op.create_table(
        "orders",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id"), nullable=False),
        sa.Column("status", orderstatus, server_default="pending", nullable=False),
        sa.Column("subtotal_mad", sa.Float(), nullable=False),
        sa.Column("delivery_fee_mad", sa.Float(), server_default="0", nullable=False),
        sa.Column("total_mad", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(length=8), server_default="MAD", nullable=False),
        sa.Column("payment_method", sa.String(length=32), server_default="cod", nullable=False),
        sa.Column("payment_status", paymentstatus, server_default="cod", nullable=False),
        sa.Column("delivery_name", sa.String(length=120), server_default="", nullable=False),
        sa.Column("delivery_phone", sa.String(length=32), server_default="", nullable=False),
        sa.Column("delivery_address", sa.String(length=255), server_default="", nullable=False),
        sa.Column("delivery_city", sa.String(length=80), server_default="", nullable=False),
        sa.Column("buyer_note", sa.Text(), server_default="", nullable=False),
        sa.Column("seller_note", sa.Text(), server_default="", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("accepted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_orders_buyer_id", "orders", ["buyer_id"])
    op.create_index("ix_orders_seller_id", "orders", ["seller_id"])
    op.create_index("ix_orders_status", "orders", ["status"])

    op.create_table(
        "order_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("order_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=True),
        sa.Column("product_name", sa.String(length=160), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price_mad", sa.Float(), nullable=False),
        sa.Column("total_mad", sa.Float(), nullable=False),
        sa.Column("image_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.create_index("ix_order_items_order_id", "order_items", ["order_id"])

    op.create_table(
        "conversations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id"), nullable=False),
        sa.Column("last_message_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("buyer_id", "seller_id", name="uq_conversation_buyer_seller"),
    )
    op.create_index("ix_conversations_buyer_id", "conversations", ["buyer_id"])
    op.create_index("ix_conversations_seller_id", "conversations", ["seller_id"])

    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("conversation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sender_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])

    op.create_table(
        "notifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("body", sa.Text(), server_default="", nullable=False),
        sa.Column("kind", sa.String(length=40), server_default="general", nullable=False),
        sa.Column("data", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])

    op.create_table(
        "coupons",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(length=40), nullable=False),
        sa.Column("description", sa.String(length=255), server_default="", nullable=False),
        sa.Column("percent_off", sa.Float(), nullable=True),
        sa.Column("amount_off_mad", sa.Float(), nullable=True),
        sa.Column("min_order_mad", sa.Float(), server_default="0", nullable=False),
        sa.Column("max_uses", sa.Integer(), server_default="100", nullable=False),
        sa.Column("used_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("seller_id", "code", name="uq_coupon_seller_code"),
    )
    op.create_index("ix_coupons_seller_id", "coupons", ["seller_id"])

    op.create_table(
        "subscription_plans",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(length=40), unique=True, nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), server_default="", nullable=False),
        sa.Column("price_mad", sa.Float(), nullable=False),
        sa.Column("billing_period_days", sa.Integer(), server_default="30", nullable=False),
        sa.Column("features", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'[]'::jsonb"), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    op.create_table(
        "subscriptions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plan_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("subscription_plans.id"), nullable=False),
        sa.Column("status", substatus, server_default="active", nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("provider", sa.String(length=40), server_default="manual", nullable=False),
        sa.Column("provider_reference", sa.String(length=120), server_default="", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_subscriptions_user_id", "subscriptions", ["user_id"])

    op.create_table(
        "admin_audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("actor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("target_type", sa.String(length=40), server_default="", nullable=False),
        sa.Column("target_id", sa.String(length=64), server_default="", nullable=False),
        sa.Column("metadata", postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_admin_audit_logs_actor_id", "admin_audit_logs", ["actor_id"])

    # Seed premium plans
    op.execute(
        """
        INSERT INTO subscription_plans (id, code, name, description, price_mad, billing_period_days, features, is_active)
        VALUES
        (gen_random_uuid(), 'buyer_premium', 'MarGem Plus', 'Buyer premium: exclusive deals, priority support, wishlist sync', 49, 30,
         '["Exclusive deals","Priority support","Unlimited wishlist","Early access"]'::jsonb, true),
        (gen_random_uuid(), 'seller_pro', 'Seller Pro', 'Boosted visibility, analytics, coupons, featured placement', 199, 30,
         '["Featured placement","Advanced analytics","Unlimited coupons","Priority verification"]'::jsonb, true)
        """
    )


def downgrade() -> None:
    for table in (
        "admin_audit_logs",
        "subscriptions",
        "subscription_plans",
        "coupons",
        "notifications",
        "messages",
        "conversations",
        "order_items",
        "orders",
        "wishlist_items",
        "cart_items",
        "buyer_addresses",
        "mfa_factors",
        "auth_tokens",
    ):
        op.drop_table(table)

    op.drop_column("seller_profiles", "order_count")
    op.drop_column("seller_profiles", "total_sales_mad")
    op.drop_column("seller_profiles", "is_premium")
    op.drop_column("seller_profiles", "verification_status")
    op.drop_column("products", "is_hidden")
    op.drop_column("products", "sku")
    op.drop_column("products", "stock_quantity")
    op.drop_column("refresh_tokens", "last_seen_at")
    op.drop_column("refresh_tokens", "user_agent")
    op.drop_column("refresh_tokens", "ip_address")
    op.drop_column("refresh_tokens", "device_name")
    op.drop_column("users", "mfa_enabled")
    op.drop_column("users", "premium_until")
    op.drop_column("users", "is_premium")
    op.drop_column("users", "last_login_at")
    op.drop_column("users", "role")
    op.drop_column("users", "status")
    op.drop_column("users", "phone")
    op.drop_column("users", "email_verified_at")

    bind = op.get_bind()
    for enum_type in (verify_status, substatus, paymentstatus, orderstatus, userrole, userstatus):
        enum_type.drop(bind, checkfirst=True)
