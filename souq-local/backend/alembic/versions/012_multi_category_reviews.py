"""Add multi-category seller review ratings."""

from alembic import op

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE reviews
          ADD COLUMN IF NOT EXISTS product_quality INTEGER,
          ADD COLUMN IF NOT EXISTS customer_service INTEGER,
          ADD COLUMN IF NOT EXISTS communication INTEGER,
          ADD COLUMN IF NOT EXISTS trustworthiness INTEGER
        """
    )

    # Backfill legacy single-score reviews into all four categories.
    op.execute(
        """
        UPDATE reviews
        SET
          product_quality = COALESCE(product_quality, rating),
          customer_service = COALESCE(customer_service, rating),
          communication = COALESCE(communication, rating),
          trustworthiness = COALESCE(trustworthiness, rating)
        WHERE product_quality IS NULL
           OR customer_service IS NULL
           OR communication IS NULL
           OR trustworthiness IS NULL
        """
    )

    op.execute(
        """
        ALTER TABLE reviews
          ALTER COLUMN product_quality SET NOT NULL,
          ALTER COLUMN customer_service SET NOT NULL,
          ALTER COLUMN communication SET NOT NULL,
          ALTER COLUMN trustworthiness SET NOT NULL
        """
    )

    op.execute(
        """
        ALTER TABLE seller_profiles
          ADD COLUMN IF NOT EXISTS avg_product_quality DOUBLE PRECISION NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS avg_customer_service DOUBLE PRECISION NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS avg_communication DOUBLE PRECISION NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS avg_trustworthiness DOUBLE PRECISION NOT NULL DEFAULT 0
        """
    )

    # Recompute seller aggregates from category means.
    op.execute(
        """
        UPDATE seller_profiles AS sp
        SET
          review_count = COALESCE(stats.review_count, 0),
          average_rating = COALESCE(stats.average_rating, 0),
          avg_product_quality = COALESCE(stats.avg_product_quality, 0),
          avg_customer_service = COALESCE(stats.avg_customer_service, 0),
          avg_communication = COALESCE(stats.avg_communication, 0),
          avg_trustworthiness = COALESCE(stats.avg_trustworthiness, 0),
          achievement_stars = COALESCE(stats.five_star_count, 0) / 100
        FROM (
          SELECT
            seller_id,
            COUNT(*)::INTEGER AS review_count,
            ROUND(
              AVG(
                (product_quality + customer_service + communication + trustworthiness) / 4.0
              )::numeric,
              2
            )::DOUBLE PRECISION AS average_rating,
            ROUND(AVG(product_quality)::numeric, 2)::DOUBLE PRECISION AS avg_product_quality,
            ROUND(AVG(customer_service)::numeric, 2)::DOUBLE PRECISION AS avg_customer_service,
            ROUND(AVG(communication)::numeric, 2)::DOUBLE PRECISION AS avg_communication,
            ROUND(AVG(trustworthiness)::numeric, 2)::DOUBLE PRECISION AS avg_trustworthiness,
            COUNT(*) FILTER (
              WHERE ROUND(
                (product_quality + customer_service + communication + trustworthiness) / 4.0
              ) = 5
            )::INTEGER AS five_star_count
          FROM reviews
          GROUP BY seller_id
        ) AS stats
        WHERE sp.id = stats.seller_id
        """
    )


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE seller_profiles
          DROP COLUMN IF EXISTS avg_product_quality,
          DROP COLUMN IF EXISTS avg_customer_service,
          DROP COLUMN IF EXISTS avg_communication,
          DROP COLUMN IF EXISTS avg_trustworthiness
        """
    )
    op.execute(
        """
        ALTER TABLE reviews
          DROP COLUMN IF EXISTS product_quality,
          DROP COLUMN IF EXISTS customer_service,
          DROP COLUMN IF EXISTS communication,
          DROP COLUMN IF EXISTS trustworthiness
        """
    )
