from __future__ import annotations

import random
from datetime import datetime, timezone
from typing import Any, Protocol

from .bracket import NotEnoughPlayersError


class Randomizer(Protocol):
    def shuffle(self, value: list[dict[str, Any]]) -> None:
        ...


REGIONS = ["NA", "EUW", "EUNE", "KR", "BR", "LAN", "LAS", "OCE", "TR", "RU", "JP", "PH", "SG", "TH", "TW", "VN"]
MAPS = ["Summoner's Rift", "ARAM", "Arena"]
ROLES = ["Top", "Jungle", "Mid", "ADC", "Support", "Fill"]
RANKS = [
    "Iron",
    "Bronze",
    "Silver",
    "Gold",
    "Platinum",
    "Emerald",
    "Diamond",
    "Master",
    "Grandmaster",
    "Challenger",
]

RANK_SCORE = {rank: index for index, rank in enumerate(RANKS)}
ROLE_ORDER = ["Top", "Jungle", "Mid", "ADC", "Support"]


def rank_score(rank: str | None) -> int:
    return RANK_SCORE.get(rank or "", 0)


def profile_label(player: dict[str, Any]) -> str:
    riot_name = player.get("riot_name")
    tag_line = player.get("tag_line")
    rank = player.get("rank") or "Unranked"
    role = player.get("preferred_role") or "Fill"
    if riot_name and tag_line:
        return f"{riot_name}#{tag_line} ({rank}, {role})"
    return f"<@{player['user_id']}> ({rank}, {role})"


def is_rank_allowed(rank: str | None, rank_min: str | None, rank_max: str | None) -> bool:
    if rank is None:
        return False
    score = rank_score(rank)
    if rank_min and score < rank_score(rank_min):
        return False
    if rank_max and score > rank_score(rank_max):
        return False
    return True


def generate_lol_bracket(
    *,
    mode: str,
    participants: list[dict[str, Any]],
    rng: Randomizer | None = None,
) -> dict[str, Any]:
    if mode == "1v1":
        return _generate_lol_one_vs_one(participants, rng=rng)
    if mode == "5v5":
        return _generate_balanced_five_vs_five(participants, rng=rng)
    raise ValueError(f"Unsupported tournament mode: {mode}")


def _generate_lol_one_vs_one(
    participants: list[dict[str, Any]],
    *,
    rng: Randomizer | None,
) -> dict[str, Any]:
    if len(participants) < 2:
        raise NotEnoughPlayersError("A League 1v1 tournament needs at least 2 checked-in players.")

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
        "game": "league_of_legends",
        "generated_at": _now(),
        "players": seeded_players,
        "rounds": [{"name": "Round 1", "matches": matches, "byes": byes}],
    }


def _generate_balanced_five_vs_five(
    participants: list[dict[str, Any]],
    *,
    rng: Randomizer | None,
) -> dict[str, Any]:
    if len(participants) < 10:
        raise NotEnoughPlayersError("A League 5v5 tournament needs at least 10 checked-in players.")

    shuffled = _shuffle(participants, rng)
    full_team_count = len(shuffled) // 5
    selected = shuffled[: full_team_count * 5]
    reserves = shuffled[full_team_count * 5 :]

    teams = [
        {
            "name": f"Team {team_number + 1}",
            "players": [],
            "rank_score": 0,
            "roles": set(),
        }
        for team_number in range(full_team_count)
    ]

    role_buckets = {
        role: sorted(
            [player for player in selected if player.get("preferred_role") == role],
            key=lambda player: rank_score(player.get("rank")),
            reverse=True,
        )
        for role in ROLE_ORDER
    }
    fill_players = sorted(
        [
            player
            for player in selected
            if player.get("preferred_role") not in ROLE_ORDER or player.get("preferred_role") == "Fill"
        ],
        key=lambda player: rank_score(player.get("rank")),
        reverse=True,
    )

    for role in ROLE_ORDER:
        for player in role_buckets[role]:
            _assign_player(teams, player, preferred_role=role)

    for player in fill_players:
        _assign_player(teams, player, preferred_role=None)

    for team in teams:
        team["players"].sort(key=lambda player: _role_sort_key(player.get("preferred_role")))
        team["average_rank_score"] = round(team["rank_score"] / max(len(team["players"]), 1), 2)
        team["average_rank"] = _rank_from_score(team["average_rank_score"])
        del team["roles"]

    teams.sort(key=lambda team: team["average_rank_score"], reverse=True)

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
        "game": "league_of_legends",
        "generated_at": _now(),
        "players": selected,
        "teams": teams,
        "reserves": reserves,
        "rounds": [{"name": "Round 1", "matches": matches, "byes": byes}],
    }


def _assign_player(
    teams: list[dict[str, Any]],
    player: dict[str, Any],
    *,
    preferred_role: str | None,
) -> None:
    eligible = [team for team in teams if len(team["players"]) < 5]
    if preferred_role:
        no_role_duplicate = [team for team in eligible if preferred_role not in team["roles"]]
        if no_role_duplicate:
            eligible = no_role_duplicate

    target = min(
        eligible,
        key=lambda team: (
            len(team["players"]),
            team["rank_score"],
            len(team["roles"]),
        ),
    )
    target["players"].append(player)
    target["rank_score"] += rank_score(player.get("rank"))
    if preferred_role:
        target["roles"].add(preferred_role)


def _role_sort_key(role: str | None) -> int:
    if role in ROLE_ORDER:
        return ROLE_ORDER.index(role)
    return len(ROLE_ORDER)


def _rank_from_score(score: float) -> str:
    index = round(score)
    index = max(0, min(index, len(RANKS) - 1))
    return RANKS[index]


def _shuffle(participants: list[dict[str, Any]], rng: Randomizer | None) -> list[dict[str, Any]]:
    shuffled = [dict(participant) for participant in participants]
    randomizer = rng or random.SystemRandom()
    randomizer.shuffle(shuffled)
    return shuffled


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
