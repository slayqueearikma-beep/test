"""Production hardening indexes and favorite uniqueness."""

from alembic import op

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Deduplicate favorites before adding unique indexes (keep oldest row).
    op.execute(
        """
        DELETE FROM favorites a
        USING favorites b
        WHERE a.product_id IS NOT NULL
          AND a.product_id = b.product_id
          AND a.user_id = b.user_id
          AND a.created_at > b.created_at
        """
    )
    op.execute(
        """
        DELETE FROM favorites a
        USING favorites b
        WHERE a.product_id IS NULL
          AND b.product_id IS NULL
          AND a.seller_id IS NOT NULL
          AND a.seller_id = b.seller_id
          AND a.user_id = b.user_id
          AND a.created_at > b.created_at
        """
    )

    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_favorites_user_product
        ON favorites (user_id, product_id)
        WHERE product_id IS NOT NULL
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_favorites_user_seller
        ON favorites (user_id, seller_id)
        WHERE product_id IS NULL AND seller_id IS NOT NULL
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_seller_follows_seller_id ON seller_follows (seller_id)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_recently_viewed_viewed_at ON recently_viewed (user_id, viewed_at DESC)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_contact_events_created_at ON contact_events (seller_id, created_at DESC)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_conversations_last_message ON conversations (last_message_at DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_conversations_last_message")
    op.execute("DROP INDEX IF EXISTS ix_contact_events_created_at")
    op.execute("DROP INDEX IF EXISTS ix_recently_viewed_viewed_at")
    op.execute("DROP INDEX IF EXISTS ix_seller_follows_seller_id")
    op.execute("DROP INDEX IF EXISTS uq_favorites_user_seller")
    op.execute("DROP INDEX IF EXISTS uq_favorites_user_product")
