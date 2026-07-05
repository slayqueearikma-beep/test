from __future__ import annotations

import random

import discord
from discord import app_commands
from discord.ext import commands

from ..storage import TournamentStore


CHALLENGES = [
    "Warm-up duel: play one quick practice match before the bracket starts.",
    "Captain callout: each team names one shot caller for the first round.",
    "MVP prediction: everyone guesses who will carry the tournament.",
    "Map veto: finalists get one ban each before the grand final.",
    "Clip bounty: best highlight from the event gets bragging rights.",
    "Underdog boost: lowest seeded player or team gets to choose first map.",
    "No-salt rule: every eliminated player posts one good play from their opponent.",
    "Caster mode: one spectator gives a one-line intro for each match.",
]


class ActivitiesCog(commands.Cog):
    activity = app_commands.Group(
        name="activity",
        description="Fun helper commands for 7amidelmath tournaments.",
    )

    def __init__(self, bot: commands.Bot, store: TournamentStore) -> None:
        self.bot = bot
        self.store = store

    @activity.command(name="challenge", description="Get a random tournament activity idea.")
    async def challenge(self, interaction: discord.Interaction) -> None:
        await interaction.response.send_message(random.choice(CHALLENGES))

    @activity.command(name="coinflip", description="Flip a coin.")
    async def coinflip(self, interaction: discord.Interaction) -> None:
        await interaction.response.send_message(f"The coin says: **{random.choice(['Heads', 'Tails'])}**")

    @activity.command(name="roll", description="Roll a die.")
    @app_commands.describe(sides="Number of sides on the die.")
    async def roll(self, interaction: discord.Interaction, sides: int = 6) -> None:
        if sides < 2 or sides > 1000:
            await interaction.response.send_message(
                "Choose between 2 and 1000 sides.",
                ephemeral=True,
            )
            return
        await interaction.response.send_message(f"You rolled **{random.randint(1, sides)}** on a d{sides}.")

    @activity.command(name="pick", description="Pick one option from a comma-separated list.")
    @app_commands.describe(options="Example: map 1, map 2, map 3")
    async def pick(self, interaction: discord.Interaction, options: str) -> None:
        choices = [option.strip() for option in options.split(",") if option.strip()]
        if len(choices) < 2:
            await interaction.response.send_message(
                "Give me at least two comma-separated options.",
                ephemeral=True,
            )
            return
        await interaction.response.send_message(f"I pick: **{random.choice(choices)}**")

    @activity.command(name="leaderboard", description="Show the most active enrolled players.")
    async def leaderboard(self, interaction: discord.Interaction) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message(
                "The leaderboard is only available inside a Discord server.",
                ephemeral=True,
            )
            return

        leaders = self.store.leaderboard(guild_id=interaction.guild_id, limit=10)
        if not leaders:
            await interaction.response.send_message("No one has enrolled in a tournament yet.")
            return

        lines = [
            f"{index}. <@{leader['user_id']}> - {leader['enrollments']} enrollments"
            for index, leader in enumerate(leaders, start=1)
        ]
        await interaction.response.send_message("**7amidelmath Activity Leaderboard**\n" + "\n".join(lines))
