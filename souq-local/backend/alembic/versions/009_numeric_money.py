"""Store money as Numeric(12,2) instead of Float."""

from alembic import op

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE products
          ALTER COLUMN price_mad TYPE NUMERIC(12, 2)
          USING ROUND(price_mad::numeric, 2)
        """
    )
    op.execute(
        """
        ALTER TABLE services
          ALTER COLUMN price_mad TYPE NUMERIC(12, 2)
          USING ROUND(price_mad::numeric, 2)
        """
    )
    op.execute(
        """
        ALTER TABLE subscription_plans
          ALTER COLUMN price_mad TYPE NUMERIC(12, 2)
          USING ROUND(price_mad::numeric, 2)
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE products ALTER COLUMN price_mad TYPE DOUBLE PRECISION USING price_mad::double precision")
    op.execute("ALTER TABLE services ALTER COLUMN price_mad TYPE DOUBLE PRECISION USING price_mad::double precision")
    op.execute(
        "ALTER TABLE subscription_plans ALTER COLUMN price_mad TYPE DOUBLE PRECISION USING price_mad::double precision"
    )
