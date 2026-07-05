import random

import pytest

from sevenamidelmath.bracket import (
    BracketProgressionError,
    NotEnoughPlayersError,
    generate_bracket,
    report_one_vs_one_winner,
)


def players(count: int) -> list[dict]:
    return [
        {
            "user_id": index,
            "display_name": f"Player {index}",
        }
        for index in range(1, count + 1)
    ]


def test_one_vs_one_pairs_players_randomly() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(4),
        rng=random.Random(7),
    )

    round_one = bracket["rounds"][0]
    assert bracket["mode"] == "1v1"
    assert len(round_one["matches"]) == 2
    assert round_one["byes"] == []

    seeded_ids = [player["user_id"] for player in bracket["players"]]
    matched_ids = [
        match[player_key]["user_id"]
        for match in round_one["matches"]
        for player_key in ("player_a", "player_b")
    ]
    assert matched_ids == seeded_ids
    assert sorted(matched_ids) == [1, 2, 3, 4]


def test_one_vs_one_adds_bye_for_odd_player_count() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(5),
        rng=random.Random(3),
    )

    round_one = bracket["rounds"][0]
    assert len(round_one["matches"]) == 2
    assert len(round_one["byes"]) == 1


def test_one_vs_one_advances_winners_to_next_round() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(4),
        rng=random.Random(7),
    )
    round_one = bracket["rounds"][0]

    first = report_one_vs_one_winner(
        bracket,
        match_number=1,
        winner_user_id=round_one["matches"][0]["player_a"]["user_id"],
    )
    second = report_one_vs_one_winner(
        bracket,
        match_number=2,
        winner_user_id=round_one["matches"][1]["player_b"]["user_id"],
    )

    assert not first["advanced"]
    assert second["advanced"]
    assert second["next_round_number"] == 2
    assert len(bracket["rounds"]) == 2
    assert bracket["rounds"][1]["name"] == "Round 2"
    assert len(bracket["rounds"][1]["matches"]) == 1


def test_one_vs_one_marks_champion_after_final() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(4),
        rng=random.Random(7),
    )
    round_one = bracket["rounds"][0]
    report_one_vs_one_winner(
        bracket,
        match_number=1,
        winner_user_id=round_one["matches"][0]["player_a"]["user_id"],
    )
    report_one_vs_one_winner(
        bracket,
        match_number=2,
        winner_user_id=round_one["matches"][1]["player_a"]["user_id"],
    )
    final = bracket["rounds"][1]["matches"][0]

    result = report_one_vs_one_winner(
        bracket,
        match_number=1,
        winner_user_id=final["player_b"]["user_id"],
    )

    assert result["completed"]
    assert bracket["completed"]
    assert bracket["champion"]["user_id"] == final["player_b"]["user_id"]


def test_one_vs_one_bye_advances_into_next_round() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(3),
        rng=random.Random(3),
    )
    round_one = bracket["rounds"][0]

    report_one_vs_one_winner(
        bracket,
        match_number=1,
        winner_user_id=round_one["matches"][0]["player_a"]["user_id"],
    )

    assert len(bracket["rounds"]) == 2
    assert bracket["rounds"][1]["matches"][0]["player_b"] == round_one["byes"][0]


def test_one_vs_one_rejects_winner_not_in_match() -> None:
    bracket = generate_bracket(
        mode="1v1",
        participants=players(2),
        rng=random.Random(1),
    )

    with pytest.raises(BracketProgressionError):
        report_one_vs_one_winner(bracket, match_number=1, winner_user_id=999)


def test_five_vs_five_builds_full_teams_and_matches() -> None:
    bracket = generate_bracket(
        mode="5v5",
        participants=players(20),
        rng=random.Random(11),
    )

    round_one = bracket["rounds"][0]
    assert bracket["mode"] == "5v5"
    assert len(bracket["teams"]) == 4
    assert all(len(team["players"]) == 5 for team in bracket["teams"])
    assert len(round_one["matches"]) == 2
    assert round_one["byes"] == []
    assert bracket["reserves"] == []


def test_five_vs_five_keeps_extra_players_as_reserves() -> None:
    bracket = generate_bracket(
        mode="5v5",
        participants=players(23),
        rng=random.Random(17),
    )

    assert len(bracket["teams"]) == 4
    assert len(bracket["reserves"]) == 3


def test_five_vs_five_adds_team_bye_for_odd_team_count() -> None:
    bracket = generate_bracket(
        mode="5v5",
        participants=players(15),
        rng=random.Random(19),
    )

    round_one = bracket["rounds"][0]
    assert len(bracket["teams"]) == 3
    assert len(round_one["matches"]) == 1
    assert len(round_one["byes"]) == 1


@pytest.mark.parametrize(
    ("mode", "count"),
    [
        ("1v1", 1),
        ("5v5", 9),
    ],
)
def test_not_enough_players(mode: str, count: int) -> None:
    with pytest.raises(NotEnoughPlayersError):
        generate_bracket(mode=mode, participants=players(count), rng=random.Random(1))
