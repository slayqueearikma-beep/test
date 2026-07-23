"""Add composite indexes for inbox and seller discovery sort paths."""

from alembic import op

revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_messages_conversation_created
          ON messages (conversation_id, created_at DESC)
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_seller_profiles_active_premium_rating
          ON seller_profiles (is_active, is_premium DESC, average_rating DESC)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_seller_profiles_active_premium_rating")
    op.execute("DROP INDEX IF EXISTS ix_messages_conversation_created")
