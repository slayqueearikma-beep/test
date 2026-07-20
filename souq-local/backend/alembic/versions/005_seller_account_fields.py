"""Add seller logo, opening hours, and profile view count.

Revision ID: 005
Revises: 004
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "seller_profiles",
        sa.Column("logo_image_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.add_column(
        "seller_profiles",
        sa.Column(
            "opening_hours",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
    )
    op.add_column(
        "seller_profiles",
        sa.Column("profile_view_count", sa.Integer(), server_default="0", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("seller_profiles", "profile_view_count")
    op.drop_column("seller_profiles", "opening_hours")
    op.drop_column("seller_profiles", "logo_image_url")
