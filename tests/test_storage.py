import sqlite3

from sevenamidelmath.storage import TournamentStore


def test_create_tournament_stores_mute_on_enroll(tmp_path) -> None:
    store = TournamentStore(tmp_path / "tournaments.db")
    store.setup()

    tournament_id = store.create_tournament(
        guild_id=1,
        channel_id=2,
        creator_id=3,
        name="Muted Tournament",
        mode="1v1",
        max_players=None,
        mute_on_enroll=True,
    )

    tournament = store.get_tournament(tournament_id)
    store.close()

    assert tournament is not None
    assert tournament["mute_on_enroll"] == 1


def test_setup_adds_mute_on_enroll_to_existing_database(tmp_path) -> None:
    database_path = tmp_path / "old.db"
    connection = sqlite3.connect(database_path)
    connection.executescript(
        """
        CREATE TABLE tournaments (
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
        """
    )
    connection.close()

    store = TournamentStore(database_path)
    store.setup()

    cursor = store._connection.execute("PRAGMA table_info(tournaments)")
    columns = {row["name"] for row in cursor.fetchall()}
    store.close()

    assert "mute_on_enroll" in columns
