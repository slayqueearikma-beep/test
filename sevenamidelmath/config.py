from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _truthy(value: str | None, *, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "y", "on"}


@dataclass(frozen=True)
class Settings:
    discord_token: str
    database_path: Path
    guild_id: int | None = None
    auto_sync_commands: bool = True

    @classmethod
    def from_environment(cls) -> "Settings":
        token = os.getenv("DISCORD_TOKEN", "").strip()
        if not token or token == "replace-me":
            raise RuntimeError(
                "DISCORD_TOKEN is not configured. Copy .env.example to .env and add your bot token."
            )

        guild_id_value = os.getenv("GUILD_ID", "").strip()
        guild_id = int(guild_id_value) if guild_id_value else None

        database_path = Path(os.getenv("DATABASE_PATH", "data/tournaments.db"))

        return cls(
            discord_token=token,
            database_path=database_path,
            guild_id=guild_id,
            auto_sync_commands=_truthy(os.getenv("AUTO_SYNC_COMMANDS"), default=True),
        )
