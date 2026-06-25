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
                    mute_on_enroll INTEGER NOT NULL DEFAULT 0,
                    game TEXT NOT NULL DEFAULT 'generic',
                    lol_region TEXT,
                    lol_map TEXT,
                    rank_min TEXT,
                    rank_max TEXT,
                    min_account_level INTEGER,
                    check_in_required INTEGER NOT NULL DEFAULT 0,
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
                    checked_in INTEGER NOT NULL DEFAULT 0,
                    joined_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (tournament_id, user_id),
                    FOREIGN KEY (tournament_id)
                        REFERENCES tournaments(id)
                        ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS league_profiles (
                    guild_id INTEGER NOT NULL,
                    user_id INTEGER NOT NULL,
                    riot_name TEXT NOT NULL,
                    tag_line TEXT NOT NULL,
                    region TEXT NOT NULL,
                    rank TEXT NOT NULL,
                    preferred_role TEXT NOT NULL,
                    account_level INTEGER,
                    verified INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (guild_id, user_id)
                );

                CREATE TABLE IF NOT EXISTS match_messages (
                    message_id INTEGER PRIMARY KEY,
                    tournament_id INTEGER NOT NULL,
                    match_number INTEGER NOT NULL,
                    thread_id INTEGER,
                    team_a_name TEXT NOT NULL,
                    team_b_name TEXT NOT NULL,
                    reported_winner TEXT,
                    reported_by INTEGER,
                    confirmed INTEGER NOT NULL DEFAULT 0,
                    disputed INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
                CREATE INDEX IF NOT EXISTS idx_league_profiles_guild
                    ON league_profiles(guild_id);
                CREATE INDEX IF NOT EXISTS idx_match_messages_tournament
                    ON match_messages(tournament_id);
                """
            )
            self._ensure_column("tournaments", "mute_on_enroll", "INTEGER NOT NULL DEFAULT 0")
            self._ensure_column("tournaments", "game", "TEXT NOT NULL DEFAULT 'generic'")
            self._ensure_column("tournaments", "lol_region", "TEXT")
            self._ensure_column("tournaments", "lol_map", "TEXT")
            self._ensure_column("tournaments", "rank_min", "TEXT")
            self._ensure_column("tournaments", "rank_max", "TEXT")
            self._ensure_column("tournaments", "min_account_level", "INTEGER")
            self._ensure_column("tournaments", "check_in_required", "INTEGER NOT NULL DEFAULT 0")
            self._ensure_column("participants", "checked_in", "INTEGER NOT NULL DEFAULT 0")

    def create_tournament(
        self,
        *,
        guild_id: int,
        channel_id: int,
        creator_id: int,
        name: str,
        mode: str,
        max_players: int | None,
        mute_on_enroll: bool = False,
        game: str = "generic",
        lol_region: str | None = None,
        lol_map: str | None = None,
        rank_min: str | None = None,
        rank_max: str | None = None,
        min_account_level: int | None = None,
        check_in_required: bool = False,
    ) -> int:
        with self._connection:
            cursor = self._connection.execute(
                """
                INSERT INTO tournaments (
                    guild_id, channel_id, creator_id, name, mode, max_players,
                    mute_on_enroll, game, lol_region, lol_map, rank_min, rank_max,
                    min_account_level, check_in_required
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    guild_id,
                    channel_id,
                    creator_id,
                    name,
                    mode,
                    max_players,
                    int(mute_on_enroll),
                    game,
                    lol_region,
                    lol_map,
                    rank_min,
                    rank_max,
                    min_account_level,
                    int(check_in_required),
                ),
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
            SELECT user_id, display_name, checked_in, joined_at
            FROM participants
            WHERE tournament_id = ?
            ORDER BY joined_at ASC, user_id ASC
            """,
            (tournament_id,),
        )
        return self._many(cursor)

    def list_lol_participants(self, tournament_id: int) -> list[ParticipantRecord]:
        tournament = self.get_tournament(tournament_id)
        if tournament is None:
            return []
        cursor = self._connection.execute(
            """
            SELECT
                p.user_id,
                p.display_name,
                p.checked_in,
                p.joined_at,
                lp.riot_name,
                lp.tag_line,
                lp.region,
                lp.rank,
                lp.preferred_role,
                lp.account_level,
                lp.verified
            FROM participants p
            LEFT JOIN league_profiles lp
                ON lp.guild_id = ? AND lp.user_id = p.user_id
            WHERE p.tournament_id = ?
            ORDER BY p.joined_at ASC, p.user_id ASC
            """,
            (tournament["guild_id"], tournament_id),
        )
        return self._many(cursor)

    def set_checked_in(self, tournament_id: int, user_id: int) -> bool:
        with self._connection:
            cursor = self._connection.execute(
                """
                UPDATE participants
                SET checked_in = 1
                WHERE tournament_id = ? AND user_id = ?
                """,
                (tournament_id, user_id),
            )
        return cursor.rowcount > 0

    def check_in_count(self, tournament_id: int) -> int:
        cursor = self._connection.execute(
            """
            SELECT COUNT(*) AS total
            FROM participants
            WHERE tournament_id = ? AND checked_in = 1
            """,
            (tournament_id,),
        )
        row = cursor.fetchone()
        return int(row["total"])

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

    def upsert_lol_profile(
        self,
        *,
        guild_id: int,
        user_id: int,
        riot_name: str,
        tag_line: str,
        region: str,
        rank: str,
        preferred_role: str,
        account_level: int | None,
        verified: bool = False,
    ) -> None:
        with self._connection:
            self._connection.execute(
                """
                INSERT INTO league_profiles (
                    guild_id, user_id, riot_name, tag_line, region, rank,
                    preferred_role, account_level, verified, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(guild_id, user_id) DO UPDATE SET
                    riot_name = excluded.riot_name,
                    tag_line = excluded.tag_line,
                    region = excluded.region,
                    rank = excluded.rank,
                    preferred_role = excluded.preferred_role,
                    account_level = excluded.account_level,
                    verified = excluded.verified,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (
                    guild_id,
                    user_id,
                    riot_name,
                    tag_line,
                    region,
                    rank,
                    preferred_role,
                    account_level,
                    int(verified),
                ),
            )

    def get_lol_profile(self, *, guild_id: int, user_id: int) -> ParticipantRecord | None:
        cursor = self._connection.execute(
            """
            SELECT *
            FROM league_profiles
            WHERE guild_id = ? AND user_id = ?
            """,
            (guild_id, user_id),
        )
        return self._one(cursor)

    def update_lol_role(self, *, guild_id: int, user_id: int, preferred_role: str) -> bool:
        with self._connection:
            cursor = self._connection.execute(
                """
                UPDATE league_profiles
                SET preferred_role = ?, updated_at = CURRENT_TIMESTAMP
                WHERE guild_id = ? AND user_id = ?
                """,
                (preferred_role, guild_id, user_id),
            )
        return cursor.rowcount > 0

    def register_match_message(
        self,
        *,
        message_id: int,
        tournament_id: int,
        match_number: int,
        thread_id: int | None,
        team_a_name: str,
        team_b_name: str,
    ) -> None:
        with self._connection:
            self._connection.execute(
                """
                INSERT OR REPLACE INTO match_messages (
                    message_id, tournament_id, match_number, thread_id,
                    team_a_name, team_b_name
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (message_id, tournament_id, match_number, thread_id, team_a_name, team_b_name),
            )

    def get_match_message(self, message_id: int) -> dict[str, Any] | None:
        cursor = self._connection.execute(
            "SELECT * FROM match_messages WHERE message_id = ?",
            (message_id,),
        )
        return self._one(cursor)

    def get_match_by_number(self, *, tournament_id: int, match_number: int) -> dict[str, Any] | None:
        cursor = self._connection.execute(
            """
            SELECT *
            FROM match_messages
            WHERE tournament_id = ? AND match_number = ?
            ORDER BY message_id DESC
            LIMIT 1
            """,
            (tournament_id, match_number),
        )
        return self._one(cursor)

    def record_match_result(
        self,
        *,
        message_id: int,
        winner_key: str,
        reporter_id: int,
    ) -> dict[str, Any] | None:
        match = self.get_match_message(message_id)
        if match is None:
            return None

        reported_winner = match.get("reported_winner")
        reported_by = match.get("reported_by")
        confirmed = bool(match.get("confirmed"))

        if confirmed:
            status = "already_confirmed"
        elif reported_winner is None:
            status = "reported"
            with self._connection:
                self._connection.execute(
                    """
                    UPDATE match_messages
                    SET reported_winner = ?,
                        reported_by = ?,
                        disputed = 0,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE message_id = ?
                    """,
                    (winner_key, reporter_id, message_id),
                )
        elif reported_winner == winner_key and reported_by != reporter_id:
            status = "confirmed"
            with self._connection:
                self._connection.execute(
                    """
                    UPDATE match_messages
                    SET confirmed = 1,
                        disputed = 0,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE message_id = ?
                    """,
                    (message_id,),
                )
        elif reported_winner == winner_key:
            status = "needs_second_confirmation"
        else:
            status = "disputed"
            with self._connection:
                self._connection.execute(
                    """
                    UPDATE match_messages
                    SET disputed = 1,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE message_id = ?
                    """,
                    (message_id,),
                )

        updated = self.get_match_message(message_id)
        if updated is None:
            return None
        updated["result_status"] = status
        return updated

    def mark_match_disputed(self, *, message_id: int, reporter_id: int) -> dict[str, Any] | None:
        if self.get_match_message(message_id) is None:
            return None
        with self._connection:
            self._connection.execute(
                """
                UPDATE match_messages
                SET disputed = 1,
                    reported_by = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE message_id = ?
                """,
                (reporter_id, message_id),
            )
        updated = self.get_match_message(message_id)
        if updated is not None:
            updated["result_status"] = "disputed"
        return updated

    def league_leaderboard(self, *, guild_id: int, limit: int = 10) -> list[ParticipantRecord]:
        cursor = self._connection.execute(
            """
            SELECT
                lp.user_id,
                lp.riot_name,
                lp.tag_line,
                lp.rank,
                lp.preferred_role,
                COUNT(DISTINCT t.id) AS tournaments,
                SUM(CASE WHEN mm.confirmed = 1 THEN 1 ELSE 0 END) AS confirmed_results
            FROM league_profiles lp
            LEFT JOIN participants p
                ON p.user_id = lp.user_id
            LEFT JOIN tournaments t
                ON t.id = p.tournament_id AND t.guild_id = lp.guild_id
            LEFT JOIN match_messages mm
                ON mm.tournament_id = t.id
            WHERE lp.guild_id = ?
            GROUP BY lp.user_id
            ORDER BY tournaments DESC, confirmed_results DESC, lp.riot_name ASC
            LIMIT ?
            """,
            (guild_id, limit),
        )
        return self._many(cursor)

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

    def _ensure_column(self, table: str, column: str, definition: str) -> None:
        cursor = self._connection.execute(f"PRAGMA table_info({table})")
        existing_columns = {row["name"] for row in cursor.fetchall()}
        if column in existing_columns:
            return
        self._connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
