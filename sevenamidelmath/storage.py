from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any


TournamentRecord = dict[str, Any]
ParticipantRecord = dict[str, Any]


class TournamentStore:
    """Small SQLite-backed repository for tournaments and enrollments."""

    def __init__(self, database_path: Path) -> None:
        self.database_path = database_path
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(self.database_path)
        self._connection.row_factory = sqlite3.Row

    def close(self) -> None:
        self._connection.close()

    def setup(self) -> None:
        with self._connection:
            self._connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS tournaments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    guild_id INTEGER NOT NULL,
                    channel_id INTEGER NOT NULL,
                    message_id INTEGER UNIQUE,
                    creator_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    mode TEXT NOT NULL CHECK (mode IN ('1v1', '5v5')),
                    max_players INTEGER,
                    status TEXT NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open', 'started', 'cancelled')),
                    bracket_json TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    started_at TEXT
                );

                CREATE TABLE IF NOT EXISTS participants (
                    tournament_id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    display_name TEXT NOT NULL,
                    joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (tournament_id, user_id),
                    FOREIGN KEY (tournament_id)
                        REFERENCES tournaments(id)
                        ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_tournaments_message
                    ON tournaments(message_id);
                CREATE INDEX IF NOT EXISTS idx_tournaments_guild_status
                    ON tournaments(guild_id, status);
                CREATE INDEX IF NOT EXISTS idx_participants_user
                    ON participants(user_id);
                """
            )

    def create_tournament(
        self,
        *,
        guild_id: int,
        channel_id: int,
        creator_id: int,
        name: str,
        mode: str,
        max_players: int | None,
    ) -> int:
        with self._connection:
            cursor = self._connection.execute(
                """
                INSERT INTO tournaments (
                    guild_id, channel_id, creator_id, name, mode, max_players
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (guild_id, channel_id, creator_id, name, mode, max_players),
            )
        return int(cursor.lastrowid)

    def set_message_id(self, tournament_id: int, message_id: int) -> None:
        with self._connection:
            self._connection.execute(
                "UPDATE tournaments SET message_id = ? WHERE id = ?",
                (message_id, tournament_id),
            )

    def get_tournament(self, tournament_id: int) -> TournamentRecord | None:
        cursor = self._connection.execute(
            "SELECT * FROM tournaments WHERE id = ?",
            (tournament_id,),
        )
        return self._one(cursor)

    def get_tournament_by_message(self, message_id: int) -> TournamentRecord | None:
        cursor = self._connection.execute(
            "SELECT * FROM tournaments WHERE message_id = ?",
            (message_id,),
        )
        return self._one(cursor)

    def latest_open_tournament(self, *, guild_id: int, channel_id: int) -> TournamentRecord | None:
        cursor = self._connection.execute(
            """
            SELECT * FROM tournaments
            WHERE guild_id = ? AND channel_id = ? AND status = 'open'
            ORDER BY id DESC
            LIMIT 1
            """,
            (guild_id, channel_id),
        )
        return self._one(cursor)

    def list_tournaments(
        self,
        *,
        guild_id: int,
        status: str | None = None,
        limit: int = 10,
    ) -> list[TournamentRecord]:
        if status is None:
            cursor = self._connection.execute(
                """
                SELECT * FROM tournaments
                WHERE guild_id = ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (guild_id, limit),
            )
        else:
            cursor = self._connection.execute(
                """
                SELECT * FROM tournaments
                WHERE guild_id = ? AND status = ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (guild_id, status, limit),
            )
        return self._many(cursor)

    def add_participant(self, tournament_id: int, user_id: int, display_name: str) -> bool:
        with self._connection:
            cursor = self._connection.execute(
                """
                INSERT OR IGNORE INTO participants (tournament_id, user_id, display_name)
                VALUES (?, ?, ?)
                """,
                (tournament_id, user_id, display_name),
            )
            if cursor.rowcount == 0:
                self._connection.execute(
                    """
                    UPDATE participants
                    SET display_name = ?
                    WHERE tournament_id = ? AND user_id = ?
                    """,
                    (display_name, tournament_id, user_id),
                )
                return False
        return True

    def remove_participant(self, tournament_id: int, user_id: int) -> bool:
        with self._connection:
            cursor = self._connection.execute(
                """
                DELETE FROM participants
                WHERE tournament_id = ? AND user_id = ?
                """,
                (tournament_id, user_id),
            )
        return cursor.rowcount > 0

    def participant_count(self, tournament_id: int) -> int:
        cursor = self._connection.execute(
            "SELECT COUNT(*) AS total FROM participants WHERE tournament_id = ?",
            (tournament_id,),
        )
        row = cursor.fetchone()
        return int(row["total"])

    def list_participants(self, tournament_id: int) -> list[ParticipantRecord]:
        cursor = self._connection.execute(
            """
            SELECT user_id, display_name, joined_at
            FROM participants
            WHERE tournament_id = ?
            ORDER BY joined_at ASC, user_id ASC
            """,
            (tournament_id,),
        )
        return self._many(cursor)

    def start_tournament(self, tournament_id: int, bracket: dict[str, Any]) -> None:
        with self._connection:
            self._connection.execute(
                """
                UPDATE tournaments
                SET status = 'started',
                    bracket_json = ?,
                    started_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (json.dumps(bracket), tournament_id),
            )

    def cancel_tournament(self, tournament_id: int) -> None:
        with self._connection:
            self._connection.execute(
                "UPDATE tournaments SET status = 'cancelled' WHERE id = ?",
                (tournament_id,),
            )

    def get_bracket(self, tournament_id: int) -> dict[str, Any] | None:
        tournament = self.get_tournament(tournament_id)
        if not tournament or not tournament.get("bracket_json"):
            return None
        return json.loads(tournament["bracket_json"])

    def leaderboard(self, *, guild_id: int, limit: int = 10) -> list[ParticipantRecord]:
        cursor = self._connection.execute(
            """
            SELECT
                p.user_id,
                MAX(p.display_name) AS display_name,
                COUNT(*) AS enrollments
            FROM participants p
            INNER JOIN tournaments t ON t.id = p.tournament_id
            WHERE t.guild_id = ?
            GROUP BY p.user_id
            ORDER BY enrollments DESC, display_name ASC
            LIMIT ?
            """,
            (guild_id, limit),
        )
        return self._many(cursor)

    @staticmethod
    def _one(cursor: sqlite3.Cursor) -> dict[str, Any] | None:
        row = cursor.fetchone()
        return dict(row) if row else None

    @staticmethod
    def _many(cursor: sqlite3.Cursor) -> list[dict[str, Any]]:
        return [dict(row) for row in cursor.fetchall()]
