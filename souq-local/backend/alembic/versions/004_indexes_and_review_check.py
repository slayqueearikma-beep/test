"""Add missing indexes and review rating constraint.

Revision ID: 004
Revises: 003
"""

from typing import Sequence, Union

from alembic import op

revision: str = "004"
down_revision: Union[str, None] = "003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index("ix_products_seller_id", "products", ["seller_id"], unique=False)
    op.create_index("ix_services_seller_id", "services", ["seller_id"], unique=False)
    op.create_index("ix_reviews_seller_id", "reviews", ["seller_id"], unique=False)
    op.create_index("ix_reviews_buyer_id", "reviews", ["buyer_id"], unique=False)
    op.create_index("ix_seller_profiles_is_active", "seller_profiles", ["is_active"], unique=False)
    op.create_check_constraint("ck_reviews_rating_range", "reviews", "rating >= 1 AND rating <= 5")


def downgrade() -> None:
    op.drop_constraint("ck_reviews_rating_range", "reviews", type_="check")
    op.drop_index("ix_seller_profiles_is_active", table_name="seller_profiles")
    op.drop_index("ix_reviews_buyer_id", table_name="reviews")
    op.drop_index("ix_reviews_seller_id", table_name="reviews")
    op.drop_index("ix_services_seller_id", table_name="services")
    op.drop_index("ix_products_seller_id", table_name="products")
