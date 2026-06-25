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
    assert "game" in columns
    assert "min_account_level" in columns
    assert "check_in_required" in columns


def test_lol_profile_checkin_and_match_result_flow(tmp_path) -> None:
    store = TournamentStore(tmp_path / "league.db")
    store.setup()
    store.upsert_lol_profile(
        guild_id=1,
        user_id=10,
        riot_name="Seven",
        tag_line="EUW",
        region="EUW",
        rank="Gold",
        preferred_role="Mid",
        account_level=100,
    )
    tournament_id = store.create_tournament(
        guild_id=1,
        channel_id=2,
        creator_id=3,
        name="League Cup",
        mode="5v5",
        max_players=None,
        game="league_of_legends",
        lol_region="EUW",
        lol_map="Summoner's Rift",
        min_account_level=30,
        check_in_required=True,
    )
    store.add_participant(tournament_id, 10, "Seven")

    assert store.set_checked_in(tournament_id, 10)
    participants = store.list_lol_participants(tournament_id)
    assert participants[0]["riot_name"] == "Seven"
    assert participants[0]["checked_in"] == 1

    store.register_match_message(
        message_id=500,
        tournament_id=tournament_id,
        match_number=1,
        thread_id=600,
        team_a_name="Team 1",
        team_b_name="Team 2",
    )
    first_report = store.record_match_result(message_id=500, winner_key="team_a", reporter_id=10)
    confirmation = store.record_match_result(message_id=500, winner_key="team_a", reporter_id=11)
    store.close()

    assert first_report is not None
    assert first_report["result_status"] == "reported"
    assert confirmation is not None
    assert confirmation["result_status"] == "confirmed"
