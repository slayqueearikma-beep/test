#!/usr/bin/env python3
"""Discord bot for starting, stopping, and checking the Azure Minecraft VM."""

from __future__ import annotations

import asyncio
import os
import subprocess
from dataclasses import dataclass

import discord
from discord import app_commands


def load_dotenv(path: str = ".env") -> None:
    """Tiny .env loader to avoid requiring extra packages."""
    if not os.path.exists(path):
        return

    with open(path, encoding="utf-8") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


@dataclass(frozen=True)
class Settings:
    token: str
    allowed_user_ids: set[int]
    resource_group: str
    vm_name: str
    minecraft_address: str | None
    guild_id: int | None


def parse_user_ids(value: str) -> set[int]:
    user_ids: set[int] = set()
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        user_ids.add(int(part))
    return user_ids


def load_settings() -> Settings:
    load_dotenv()

    token = os.environ.get("DISCORD_TOKEN", "").strip()
    allowed_user_ids = parse_user_ids(os.environ.get("DISCORD_ALLOWED_USER_IDS", ""))
    resource_group = os.environ.get("AZURE_RESOURCE_GROUP", "").strip()
    vm_name = os.environ.get("AZURE_VM_NAME", "").strip()
    minecraft_address = os.environ.get("MINECRAFT_SERVER_ADDRESS", "").strip() or None
    guild_id_raw = os.environ.get("DISCORD_GUILD_ID", "").strip()
    guild_id = int(guild_id_raw) if guild_id_raw else None

    missing = []
    if not token:
        missing.append("DISCORD_TOKEN")
    if not allowed_user_ids:
        missing.append("DISCORD_ALLOWED_USER_IDS")
    if not resource_group:
        missing.append("AZURE_RESOURCE_GROUP")
    if not vm_name:
        missing.append("AZURE_VM_NAME")
    if missing:
        raise RuntimeError(f"Missing required settings: {', '.join(missing)}")

    return Settings(
        token=token,
        allowed_user_ids=allowed_user_ids,
        resource_group=resource_group,
        vm_name=vm_name,
        minecraft_address=minecraft_address,
        guild_id=guild_id,
    )


SETTINGS = load_settings()


class LabBot(discord.Client):
    def __init__(self) -> None:
        intents = discord.Intents.default()
        super().__init__(intents=intents)
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self) -> None:
        if SETTINGS.guild_id is not None:
            guild = discord.Object(id=SETTINGS.guild_id)
            self.tree.copy_global_to(guild=guild)
            await self.tree.sync(guild=guild)
        else:
            await self.tree.sync()


bot = LabBot()


def is_allowed(user: discord.abc.User) -> bool:
    return user.id in SETTINGS.allowed_user_ids


async def require_allowed(interaction: discord.Interaction) -> bool:
    if is_allowed(interaction.user):
        return True

    await interaction.response.send_message(
        "You are not allowed to control this lab.",
        ephemeral=True,
    )
    return False


def run_az(command: list[str]) -> str:
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.strip()


async def run_az_async(command: list[str]) -> str:
    return await asyncio.to_thread(run_az, command)


async def azure_action(interaction: discord.Interaction, action: str) -> None:
    if not await require_allowed(interaction):
        return

    await interaction.response.defer(thinking=True)
    try:
        await run_az_async(
            [
                "az",
                "vm",
                action,
                "--resource-group",
                SETTINGS.resource_group,
                "--name",
                SETTINGS.vm_name,
            ]
        )
    except FileNotFoundError:
        await interaction.followup.send("Azure CLI was not found on the bot host.")
        return
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip() or str(exc)
        await interaction.followup.send(f"Azure command failed:\n```text\n{message[:1800]}\n```")
        return

    if action == "start":
        address = f"\nMinecraft address: `{SETTINGS.minecraft_address}`" if SETTINGS.minecraft_address else ""
        await interaction.followup.send(f"Started VM `{SETTINGS.vm_name}`.{address}")
    elif action == "deallocate":
        await interaction.followup.send(
            f"Deallocated VM `{SETTINGS.vm_name}`. Compute billing is stopped."
        )


@bot.tree.command(name="startlab", description="Start the Azure Minecraft VM.")
async def start_lab(interaction: discord.Interaction) -> None:
    await azure_action(interaction, "start")


@bot.tree.command(name="stoplab", description="Deallocate the Azure Minecraft VM to stop billing.")
async def stop_lab(interaction: discord.Interaction) -> None:
    await azure_action(interaction, "deallocate")


@bot.tree.command(name="statuslab", description="Show Azure Minecraft VM power state.")
async def status_lab(interaction: discord.Interaction) -> None:
    if not await require_allowed(interaction):
        return

    await interaction.response.defer(thinking=True)
    try:
        output = await run_az_async(
            [
                "az",
                "vm",
                "get-instance-view",
                "--resource-group",
                SETTINGS.resource_group,
                "--name",
                SETTINGS.vm_name,
                "--query",
                "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]",
                "-o",
                "tsv",
            ]
        )
    except FileNotFoundError:
        await interaction.followup.send("Azure CLI was not found on the bot host.")
        return
    except subprocess.CalledProcessError as exc:
        message = exc.stderr.strip() or exc.stdout.strip() or str(exc)
        await interaction.followup.send(f"Azure command failed:\n```text\n{message[:1800]}\n```")
        return

    address = f"\nMinecraft address: `{SETTINGS.minecraft_address}`" if SETTINGS.minecraft_address else ""
    await interaction.followup.send(f"VM `{SETTINGS.vm_name}` status: `{output or 'unknown'}`{address}")


@bot.event
async def on_ready() -> None:
    print(f"Logged in as {bot.user} (allowed users: {sorted(SETTINGS.allowed_user_ids)})")


if __name__ == "__main__":
    bot.run(SETTINGS.token)
