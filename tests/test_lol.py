import random

import pytest

from sevenamidelmath.bracket import NotEnoughPlayersError
from sevenamidelmath.lol import ROLE_ORDER, generate_lol_bracket, is_rank_allowed


def player(index: int, rank: str, role: str) -> dict:
    return {
        "user_id": index,
        "display_name": f"Player {index}",
        "riot_name": f"Riot{index}",
        "tag_line": "NA1",
        "rank": rank,
        "preferred_role": role,
    }


def test_lol_5v5_generates_rank_and_role_balanced_teams() -> None:
    ranks = ["Diamond", "Emerald", "Platinum", "Gold", "Silver"] * 2
    participants = [
        player(index + 1, rank, ROLE_ORDER[index % len(ROLE_ORDER)])
        for index, rank in enumerate(ranks)
    ]

    bracket = generate_lol_bracket(
        mode="5v5",
        participants=participants,
        rng=random.Random(5),
    )

    assert bracket["game"] == "league_of_legends"
    assert len(bracket["teams"]) == 2
    assert all(len(team["players"]) == 5 for team in bracket["teams"])
    assert all("average_rank" in team for team in bracket["teams"])
    assert len(bracket["rounds"][0]["matches"]) == 1


def test_lol_5v5_keeps_reserves() -> None:
    participants = [
        player(index + 1, "Gold", ROLE_ORDER[index % len(ROLE_ORDER)])
        for index in range(13)
    ]

    bracket = generate_lol_bracket(
        mode="5v5",
        participants=participants,
        rng=random.Random(10),
    )

    assert len(bracket["teams"]) == 2
    assert len(bracket["reserves"]) == 3


def test_lol_5v5_requires_ten_players() -> None:
    with pytest.raises(NotEnoughPlayersError):
        generate_lol_bracket(mode="5v5", participants=[player(1, "Gold", "Mid")])


def test_rank_limits() -> None:
    assert is_rank_allowed("Gold", "Silver", "Platinum")
    assert not is_rank_allowed("Bronze", "Silver", "Platinum")
    assert not is_rank_allowed("Diamond", "Silver", "Platinum")
