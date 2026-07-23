"""Add golden crowns earned from 1000 five-star review milestones."""

from alembic import op

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE seller_profiles
          ADD COLUMN IF NOT EXISTS golden_crowns INTEGER NOT NULL DEFAULT 0
        """
    )

    # Convert existing achievement stars: every 10 stars (1000 five-star reviews) → 1 crown.
    op.execute(
        """
        UPDATE seller_profiles
        SET
          golden_crowns = achievement_stars / 10,
          achievement_stars = achievement_stars % 10
        WHERE achievement_stars >= 10
        """
    )


def downgrade() -> None:
    op.execute(
        """
        UPDATE seller_profiles
        SET achievement_stars = (golden_crowns * 10) + achievement_stars
        """
    )
    op.execute(
        """
        ALTER TABLE seller_profiles
          DROP COLUMN IF EXISTS golden_crowns
        """
    )
