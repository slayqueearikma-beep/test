from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Any, Protocol


class Randomizer(Protocol):
    def shuffle(self, value: list[dict[str, Any]]) -> None:
        ...


class NotEnoughPlayersError(ValueError):
    pass


def minimum_players_for_mode(mode: str) -> int:
    if mode == "1v1":
        return 2
    if mode == "5v5":
        return 10
    raise ValueError(f"Unsupported tournament mode: {mode}")


def generate_bracket(
    *,
    mode: str,
    participants: list[dict[str, Any]],
    rng: Randomizer | None = None,
) -> dict[str, Any]:
    if mode == "1v1":
        return _generate_one_vs_one(participants, rng=rng)
    if mode == "5v5":
        return _generate_five_vs_five(participants, rng=rng)
    raise ValueError(f"Unsupported tournament mode: {mode}")


def _generate_one_vs_one(
    participants: list[dict[str, Any]],
    *,
    rng: Randomizer | None,
) -> dict[str, Any]:
    if len(participants) < minimum_players_for_mode("1v1"):
        raise NotEnoughPlayersError("A 1v1 tournament needs at least 2 enrolled players.")

    seeded_players = _shuffle(participants, rng)
    matches: list[dict[str, Any]] = []
    byes: list[dict[str, Any]] = []

    for index in range(0, len(seeded_players), 2):
        player_a = seeded_players[index]
        player_b = seeded_players[index + 1] if index + 1 < len(seeded_players) else None
        if player_b is None:
            byes.append(player_a)
            continue

        matches.append(
            {
                "match_number": len(matches) + 1,
                "player_a": player_a,
                "player_b": player_b,
            }
        )

    return {
        "mode": "1v1",
        "generated_at": _now(),
        "players": seeded_players,
        "rounds": [
            {
                "name": "Round 1",
                "matches": matches,
                "byes": byes,
            }
        ],
    }


def _generate_five_vs_five(
    participants: list[dict[str, Any]],
    *,
    rng: Randomizer | None,
) -> dict[str, Any]:
    if len(participants) < minimum_players_for_mode("5v5"):
        raise NotEnoughPlayersError("A 5v5 tournament needs at least 10 enrolled players.")

    seeded_players = _shuffle(participants, rng)
    full_team_count = len(seeded_players) // 5
    if full_team_count < 2:
        raise NotEnoughPlayersError("A 5v5 tournament needs at least 2 full teams.")

    teams = [
        {
            "name": f"Team {team_number + 1}",
            "players": seeded_players[team_number * 5 : (team_number + 1) * 5],
        }
        for team_number in range(full_team_count)
    ]
    reserves = seeded_players[full_team_count * 5 :]

    matches: list[dict[str, Any]] = []
    byes: list[dict[str, Any]] = []
    for index in range(0, len(teams), 2):
        team_a = teams[index]
        team_b = teams[index + 1] if index + 1 < len(teams) else None
        if team_b is None:
            byes.append(team_a)
            continue

        matches.append(
            {
                "match_number": len(matches) + 1,
                "team_a": team_a,
                "team_b": team_b,
            }
        )

    return {
        "mode": "5v5",
        "generated_at": _now(),
        "players": seeded_players,
        "teams": teams,
        "reserves": reserves,
        "rounds": [
            {
                "name": "Round 1",
                "matches": matches,
                "byes": byes,
            }
        ],
    }


def _shuffle(participants: list[dict[str, Any]], rng: Randomizer | None) -> list[dict[str, Any]]:
    shuffled = [dict(participant) for participant in participants]
    randomizer = rng or random.SystemRandom()
    randomizer.shuffle(shuffled)
    return shuffled


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
