"""Migrate conversations from buyer/seller storefront pairs to user↔user participants."""

from alembic import op

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE conversations
          ADD COLUMN IF NOT EXISTS participant_a_id UUID,
          ADD COLUMN IF NOT EXISTS participant_b_id UUID,
          ADD COLUMN IF NOT EXISTS context_seller_id UUID
        """
    )

    # Backfill from legacy buyer_id + seller_profiles.user_id.
    op.execute(
        """
        UPDATE conversations AS c
        SET
          participant_a_id = LEAST(c.buyer_id, sp.user_id),
          participant_b_id = GREATEST(c.buyer_id, sp.user_id),
          context_seller_id = c.seller_id
        FROM seller_profiles AS sp
        WHERE sp.id = c.seller_id
          AND (c.participant_a_id IS NULL OR c.participant_b_id IS NULL)
        """
    )

    # Merge duplicate seller↔seller pairs: keep oldest conversation, move messages, drop extras.
    op.execute(
        """
        WITH ranked AS (
          SELECT
            id,
            participant_a_id,
            participant_b_id,
            ROW_NUMBER() OVER (
              PARTITION BY participant_a_id, participant_b_id
              ORDER BY created_at ASC, id ASC
            ) AS rn
          FROM conversations
          WHERE participant_a_id IS NOT NULL AND participant_b_id IS NOT NULL
        ),
        dupes AS (
          SELECT id, participant_a_id, participant_b_id
          FROM ranked
          WHERE rn > 1
        ),
        keepers AS (
          SELECT id, participant_a_id, participant_b_id
          FROM ranked
          WHERE rn = 1
        )
        UPDATE messages AS m
        SET conversation_id = k.id
        FROM dupes AS d
        JOIN keepers AS k
          ON k.participant_a_id = d.participant_a_id
         AND k.participant_b_id = d.participant_b_id
        WHERE m.conversation_id = d.id
        """
    )
    op.execute(
        """
        DELETE FROM conversations AS c
        USING (
          SELECT id
          FROM (
            SELECT
              id,
              ROW_NUMBER() OVER (
                PARTITION BY participant_a_id, participant_b_id
                ORDER BY created_at ASC, id ASC
              ) AS rn
            FROM conversations
            WHERE participant_a_id IS NOT NULL AND participant_b_id IS NOT NULL
          ) ranked
          WHERE rn > 1
        ) AS d
        WHERE c.id = d.id
        """
    )

    op.execute(
        """
        ALTER TABLE conversations
          ALTER COLUMN participant_a_id SET NOT NULL,
          ALTER COLUMN participant_b_id SET NOT NULL
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_conversations_participant_a'
          ) THEN
            ALTER TABLE conversations
              ADD CONSTRAINT fk_conversations_participant_a
              FOREIGN KEY (participant_a_id) REFERENCES users(id);
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_conversations_participant_b'
          ) THEN
            ALTER TABLE conversations
              ADD CONSTRAINT fk_conversations_participant_b
              FOREIGN KEY (participant_b_id) REFERENCES users(id);
          END IF;
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'fk_conversations_context_seller'
          ) THEN
            ALTER TABLE conversations
              ADD CONSTRAINT fk_conversations_context_seller
              FOREIGN KEY (context_seller_id) REFERENCES seller_profiles(id) ON DELETE SET NULL;
          END IF;
        END $$;
        """
    )
    op.execute("CREATE INDEX IF NOT EXISTS ix_conversations_participant_a_id ON conversations (participant_a_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_conversations_participant_b_id ON conversations (participant_b_id)")
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_conversations_context_seller_id ON conversations (context_seller_id)"
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'uq_conversation_participants'
          ) THEN
            ALTER TABLE conversations
              ADD CONSTRAINT uq_conversation_participants
              UNIQUE (participant_a_id, participant_b_id);
          END IF;
        END $$;
        """
    )

    # Drop legacy storefront-pair columns/constraints when present.
    op.execute("ALTER TABLE conversations DROP CONSTRAINT IF EXISTS uq_conversation_buyer_seller")
    op.execute("ALTER TABLE conversations DROP COLUMN IF EXISTS buyer_id")
    op.execute("ALTER TABLE conversations DROP COLUMN IF EXISTS seller_id")


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE conversations
          ADD COLUMN IF NOT EXISTS buyer_id UUID,
          ADD COLUMN IF NOT EXISTS seller_id UUID
        """
    )
    op.execute(
        """
        UPDATE conversations AS c
        SET
          buyer_id = c.participant_a_id,
          seller_id = c.context_seller_id
        WHERE c.buyer_id IS NULL
        """
    )
    # Best-effort only — peer chats without context_seller_id cannot be restored cleanly.
    op.execute("DELETE FROM conversations WHERE seller_id IS NULL")
    op.execute(
        """
        ALTER TABLE conversations
          ALTER COLUMN buyer_id SET NOT NULL,
          ALTER COLUMN seller_id SET NOT NULL
        """
    )
    op.execute("ALTER TABLE conversations DROP CONSTRAINT IF EXISTS uq_conversation_participants")
    op.execute("ALTER TABLE conversations DROP CONSTRAINT IF EXISTS fk_conversations_participant_a")
    op.execute("ALTER TABLE conversations DROP CONSTRAINT IF EXISTS fk_conversations_participant_b")
    op.execute("ALTER TABLE conversations DROP CONSTRAINT IF EXISTS fk_conversations_context_seller")
    op.execute("DROP INDEX IF EXISTS ix_conversations_participant_a_id")
    op.execute("DROP INDEX IF EXISTS ix_conversations_participant_b_id")
    op.execute("DROP INDEX IF EXISTS ix_conversations_context_seller_id")
    op.execute("ALTER TABLE conversations DROP COLUMN IF EXISTS participant_a_id")
    op.execute("ALTER TABLE conversations DROP COLUMN IF EXISTS participant_b_id")
    op.execute("ALTER TABLE conversations DROP COLUMN IF EXISTS context_seller_id")
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'uq_conversation_buyer_seller'
          ) THEN
            ALTER TABLE conversations
              ADD CONSTRAINT uq_conversation_buyer_seller UNIQUE (buyer_id, seller_id);
          END IF;
        END $$;
        """
    )
