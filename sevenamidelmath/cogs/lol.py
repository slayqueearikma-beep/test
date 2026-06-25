from __future__ import annotations

import random

import discord
from discord import app_commands
from discord.ext import commands

from ..bracket import minimum_players_for_mode
from ..lol import MAPS, RANKS, REGIONS, ROLES
from ..presentation import enrollment_embed
from ..storage import TournamentStore
from ..views import EnrollmentView


def _choices(values: list[str]) -> list[app_commands.Choice[str]]:
    return [app_commands.Choice(name=value, value=value) for value in values]


class LeagueCog(commands.Cog):
    lol = app_commands.Group(
        name="lol",
        description="League of Legends tournament tools for 7amidelmath.",
    )

    def __init__(self, bot: commands.Bot, store: TournamentStore) -> None:
        self.bot = bot
        self.store = store

    @lol.command(name="link", description="Link your Riot profile for League tournaments.")
    @app_commands.describe(
        riot_name="Your Riot game name before the #.",
        tag_line="Your Riot tag after the #.",
        region="Your Riot region.",
        rank="Your current rank.",
        role="Your preferred LoL role.",
        account_level="Optional account level for anti-smurf checks.",
    )
    @app_commands.choices(region=_choices(REGIONS), rank=_choices(RANKS), role=_choices(ROLES))
    async def link(
        self,
        interaction: discord.Interaction,
        riot_name: str,
        tag_line: str,
        region: app_commands.Choice[str],
        rank: app_commands.Choice[str],
        role: app_commands.Choice[str],
        account_level: int | None = None,
    ) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message("Link your Riot profile inside a server.", ephemeral=True)
            return

        self.store.upsert_lol_profile(
            guild_id=interaction.guild_id,
            user_id=interaction.user.id,
            riot_name=riot_name.strip()[:32],
            tag_line=tag_line.strip().lstrip("#")[:12],
            region=region.value,
            rank=rank.value,
            preferred_role=role.value,
            account_level=account_level,
            verified=False,
        )
        await interaction.response.send_message(
            f"Linked **{riot_name}#{tag_line.lstrip('#')}** as {rank.value} {role.value} on {region.value}.",
            ephemeral=True,
        )

    @lol.command(name="profile", description="Show a linked League profile.")
    @app_commands.describe(member="Player to inspect. Defaults to yourself.")
    async def profile(
        self,
        interaction: discord.Interaction,
        member: discord.Member | None = None,
    ) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message("Profiles are server-specific.", ephemeral=True)
            return

        target = member or interaction.user
        profile = self.store.get_lol_profile(guild_id=interaction.guild_id, user_id=target.id)
        if profile is None:
            await interaction.response.send_message("No League profile linked yet.", ephemeral=True)
            return

        embed = discord.Embed(title=f"LoL Profile: {target.display_name}", color=discord.Color.green())
        embed.add_field(name="Riot ID", value=f"{profile['riot_name']}#{profile['tag_line']}", inline=True)
        embed.add_field(name="Region", value=profile["region"], inline=True)
        embed.add_field(name="Rank", value=profile["rank"], inline=True)
        embed.add_field(name="Role", value=profile["preferred_role"], inline=True)
        embed.add_field(name="Account level", value=str(profile.get("account_level") or "Not set"), inline=True)
        embed.add_field(name="Verified", value="Manual link", inline=True)
        await interaction.response.send_message(embed=embed)

    @lol.command(name="role", description="Update your preferred League role.")
    @app_commands.choices(role=_choices(ROLES))
    async def role(self, interaction: discord.Interaction, role: app_commands.Choice[str]) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message("Roles are server-specific.", ephemeral=True)
            return

        updated = self.store.update_lol_role(
            guild_id=interaction.guild_id,
            user_id=interaction.user.id,
            preferred_role=role.value,
        )
        if not updated:
            await interaction.response.send_message("Link your profile first with `/lol link`.", ephemeral=True)
            return
        await interaction.response.send_message(f"Updated preferred role to **{role.value}**.", ephemeral=True)

    @lol.command(name="create", description="Create a League of Legends tournament lobby.")
    @app_commands.describe(
        mode="Tournament size.",
        name="Tournament name.",
        region="Allowed Riot region. Leave blank for any.",
        map_name="League map or game mode.",
        rank_min="Minimum rank allowed.",
        rank_max="Maximum rank allowed.",
        min_account_level="Optional minimum account level for anti-smurf checks.",
        max_players="Optional enrollment cap.",
        check_in_required="Require players to check in before bracket generation.",
        mute_on_enroll="Voice-mute players who enroll while already in voice.",
    )
    @app_commands.choices(
        mode=[
            app_commands.Choice(name="1 vs 1", value="1v1"),
            app_commands.Choice(name="5 vs 5", value="5v5"),
        ],
        region=_choices(REGIONS),
        map_name=_choices(MAPS),
        rank_min=_choices(RANKS),
        rank_max=_choices(RANKS),
    )
    async def create(
        self,
        interaction: discord.Interaction,
        mode: app_commands.Choice[str],
        name: str = "League Tournament",
        region: app_commands.Choice[str] | None = None,
        map_name: app_commands.Choice[str] | None = None,
        rank_min: app_commands.Choice[str] | None = None,
        rank_max: app_commands.Choice[str] | None = None,
        min_account_level: int | None = None,
        max_players: int | None = None,
        check_in_required: bool = True,
        mute_on_enroll: bool = False,
    ) -> None:
        if interaction.guild_id is None or interaction.channel_id is None:
            await interaction.response.send_message("Create League tournaments inside a server.", ephemeral=True)
            return

        if max_players is not None and max_players < minimum_players_for_mode(mode.value):
            await interaction.response.send_message(
                f"{mode.name} needs at least {minimum_players_for_mode(mode.value)} players.",
                ephemeral=True,
            )
            return

        if rank_min and rank_max and RANKS.index(rank_min.value) > RANKS.index(rank_max.value):
            await interaction.response.send_message("Minimum rank cannot be higher than maximum rank.", ephemeral=True)
            return

        tournament_id = self.store.create_tournament(
            guild_id=interaction.guild_id,
            channel_id=interaction.channel_id,
            creator_id=interaction.user.id,
            name=name.strip()[:80] or "League Tournament",
            mode=mode.value,
            max_players=max_players,
            mute_on_enroll=mute_on_enroll,
            game="league_of_legends",
            lol_region=region.value if region else None,
            lol_map=map_name.value if map_name else "Summoner's Rift",
            rank_min=rank_min.value if rank_min else None,
            rank_max=rank_max.value if rank_max else None,
            min_account_level=min_account_level,
            check_in_required=check_in_required,
        )
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message("Something went wrong while creating the tournament.", ephemeral=True)
            return

        await interaction.response.send_message(
            embed=enrollment_embed(tournament, []),
            view=EnrollmentView(self.store),
        )
        message = await interaction.original_response()
        self.store.set_message_id(tournament_id, message.id)

    @lol.command(name="checkin", description="Check in for a League tournament.")
    @app_commands.describe(tournament_id="Tournament ID.")
    async def checkin(self, interaction: discord.Interaction, tournament_id: int) -> None:
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None or tournament.get("game") != "league_of_legends":
            await interaction.response.send_message("I could not find that League tournament.", ephemeral=True)
            return
        if tournament["status"] != "open":
            await interaction.response.send_message("Check-in is closed.", ephemeral=True)
            return
        if not tournament.get("check_in_required"):
            await interaction.response.send_message("This tournament does not require check-in.", ephemeral=True)
            return
        checked_in = self.store.set_checked_in(tournament_id, interaction.user.id)
        if not checked_in:
            await interaction.response.send_message("Enroll first, then check in.", ephemeral=True)
            return
        await interaction.response.send_message("You are checked in.", ephemeral=True)

    @lol.command(name="checkins", description="Show League tournament check-in status.")
    @app_commands.describe(tournament_id="Tournament ID.")
    async def checkins(self, interaction: discord.Interaction, tournament_id: int) -> None:
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message("I could not find that tournament.", ephemeral=True)
            return
        participants = self.store.list_lol_participants(tournament_id)
        checked_in = [participant for participant in participants if participant.get("checked_in")]
        await interaction.response.send_message(
            f"Checked in: **{len(checked_in)} / {len(participants)}**",
            ephemeral=True,
        )

    @lol.command(name="leaderboard", description="Show League tournament activity leaders.")
    async def leaderboard(self, interaction: discord.Interaction) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message("Leaderboards are server-specific.", ephemeral=True)
            return
        leaders = self.store.league_leaderboard(guild_id=interaction.guild_id, limit=10)
        if not leaders:
            await interaction.response.send_message("No linked League profiles yet.")
            return
        lines = [
            f"{index}. <@{leader['user_id']}> - {leader['riot_name']}#{leader['tag_line']} "
            f"({leader['rank']} {leader['preferred_role']}) - {leader['tournaments']} tournaments"
            for index, leader in enumerate(leaders, start=1)
        ]
        await interaction.response.send_message("**League Leaderboard**\n" + "\n".join(lines))

    @lol.command(name="player", description="Show League player tournament info.")
    @app_commands.describe(member="Player to inspect.")
    async def player(self, interaction: discord.Interaction, member: discord.Member) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message("Player info is server-specific.", ephemeral=True)
            return
        profile = self.store.get_lol_profile(guild_id=interaction.guild_id, user_id=member.id)
        if profile is None:
            await interaction.response.send_message("That player has not linked a League profile.", ephemeral=True)
            return
        await interaction.response.send_message(
            f"**{member.display_name}**: {profile['riot_name']}#{profile['tag_line']} - "
            f"{profile['region']} - {profile['rank']} - {profile['preferred_role']}"
        )

    @lol.command(name="result", description="Report or confirm a match result manually.")
    @app_commands.describe(
        tournament_id="Tournament ID.",
        match_number="Match number.",
        winner="Which side won.",
    )
    @app_commands.choices(
        winner=[
            app_commands.Choice(name="Team A / Player A", value="team_a"),
            app_commands.Choice(name="Team B / Player B", value="team_b"),
        ]
    )
    async def result(
        self,
        interaction: discord.Interaction,
        tournament_id: int,
        match_number: int,
        winner: app_commands.Choice[str],
    ) -> None:
        match = self.store.get_match_by_number(tournament_id=tournament_id, match_number=match_number)
        if match is None:
            await interaction.response.send_message(
                "I could not find a result-enabled match message. Start the tournament first.",
                ephemeral=True,
            )
            return
        result = self.store.record_match_result(
            message_id=match["message_id"],
            winner_key=winner.value,
            reporter_id=interaction.user.id,
        )
        if result is None:
            await interaction.response.send_message("I could not record that result.", ephemeral=True)
            return
        winner_name = result["team_a_name"] if winner.value == "team_a" else result["team_b_name"]
        await interaction.response.send_message(
            f"Recorded result for match {match_number}: **{winner_name}**. Status: {result['result_status']}."
        )

    @lol.command(name="rules", description="Show recommended League tournament rules.")
    async def rules(self, interaction: discord.Interaction) -> None:
        rules = "\n".join(
            [
                "1. Link your Riot account with `/lol link` before enrolling.",
                "2. Pick your real preferred role with `/lol role`.",
                "3. Check in before bracket generation if required.",
                "4. Join your match thread when it is created.",
                "5. Captains report results with buttons or `/lol result`.",
                "6. Use Dispute if a result is wrong.",
            ]
        )
        await interaction.response.send_message(f"**7amidelmath League Rules**\n{rules}")

    @lol.command(name="draft", description="Coinflip side selection and draft order for a match.")
    @app_commands.describe(team_a="First team or captain name.", team_b="Second team or captain name.")
    async def draft(self, interaction: discord.Interaction, team_a: str, team_b: str) -> None:
        side_winner = random.choice([team_a, team_b])
        other_team = team_b if side_winner == team_a else team_a
        order = "\n".join(
            [
                f"Coinflip winner: **{side_winner}**",
                f"Side choice: **{side_winner}** chooses Blue or Red side.",
                f"Draft note: **{other_team}** gets the next lobby/draft preference if your rules allow it.",
                "Recommended ban phase: each team announces bans in match thread before lobby start.",
            ]
        )
        await interaction.response.send_message(f"**League Draft Helper**\n{order}")
