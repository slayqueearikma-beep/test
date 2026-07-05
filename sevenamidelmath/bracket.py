from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Any, Protocol


class Randomizer(Protocol):
    def shuffle(self, value: list[dict[str, Any]]) -> None:
        ...


class NotEnoughPlayersError(ValueError):
    pass


class BracketProgressionError(ValueError):
    pass


def minimum_players_for_mode(mode: str) -> int:
    if mode == "1v1":
        return 2
    if mode == "5v5":
        return 10
    raise ValueError(f"Unsupported tournament mode: {mode}")


def report_one_vs_one_winner(
    bracket: dict[str, Any],
    *,
    match_number: int,
    winner_user_id: int,
    round_number: int | None = None,
) -> dict[str, Any]:
    if bracket.get("mode") != "1v1":
        raise BracketProgressionError("Winner progression is currently supported for 1v1 brackets.")

    rounds = bracket.get("rounds", [])
    if not rounds:
        raise BracketProgressionError("This bracket does not have any rounds.")

    round_index = len(rounds) - 1 if round_number is None else round_number - 1
    if round_index < 0 or round_index >= len(rounds):
        raise BracketProgressionError("That round does not exist.")

    if round_index < len(rounds) - 1:
        raise BracketProgressionError("That round already advanced. Later rounds are locked.")

    current_round = rounds[round_index]
    match = _find_match(current_round, match_number)
    if match is None:
        raise BracketProgressionError("That match does not exist in this round.")

    winner = _winner_from_match(match, winner_user_id)
    if winner is None:
        raise BracketProgressionError("Winner must be one of the players in that match.")

    if match.get("winner_user_id") and match["winner_user_id"] != winner_user_id:
        raise BracketProgressionError("That match already has a different winner recorded.")

    match["winner_user_id"] = winner_user_id
    match["winner"] = winner

    result: dict[str, Any] = {
        "bracket": bracket,
        "winner": winner,
        "round_number": round_index + 1,
        "match_number": match_number,
        "advanced": False,
        "completed": False,
        "next_round_number": None,
    }

    if not _round_complete(current_round):
        return result

    advancers = [match["winner"] for match in current_round["matches"]]
    advancers.extend(current_round.get("byes", []))

    if len(advancers) == 1:
        bracket["champion"] = advancers[0]
        bracket["completed"] = True
        bracket["completed_at"] = _now()
        result["completed"] = True
        return result

    next_round = _build_one_vs_one_round(len(rounds) + 1, advancers)
    rounds.append(next_round)
    result["advanced"] = True
    result["next_round_number"] = len(rounds)

    if not next_round["matches"] and len(next_round.get("byes", [])) == 1:
        bracket["champion"] = next_round["byes"][0]
        bracket["completed"] = True
        bracket["completed_at"] = _now()
        result["completed"] = True

    return result


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
    return {
        "mode": "1v1",
        "generated_at": _now(),
        "players": seeded_players,
        "rounds": [_build_one_vs_one_round(1, seeded_players)],
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


def _build_one_vs_one_round(round_number: int, players: list[dict[str, Any]]) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []
    byes: list[dict[str, Any]] = []

    for index in range(0, len(players), 2):
        player_a = players[index]
        player_b = players[index + 1] if index + 1 < len(players) else None
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
        "name": f"Round {round_number}",
        "matches": matches,
        "byes": byes,
    }


def _find_match(round_data: dict[str, Any], match_number: int) -> dict[str, Any] | None:
    for match in round_data.get("matches", []):
        if match.get("match_number") == match_number:
            return match
    return None


def _winner_from_match(match: dict[str, Any], winner_user_id: int) -> dict[str, Any] | None:
    for key in ("player_a", "player_b"):
        player = match.get(key)
        if player and player.get("user_id") == winner_user_id:
            return player
    return None


def _round_complete(round_data: dict[str, Any]) -> bool:
    return all(match.get("winner_user_id") for match in round_data.get("matches", []))


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
