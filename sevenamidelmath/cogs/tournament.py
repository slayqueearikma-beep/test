from __future__ import annotations

from typing import Any

import discord
from discord import app_commands
from discord.ext import commands

from ..bracket import (
    BracketProgressionError,
    NotEnoughPlayersError,
    generate_bracket,
    minimum_players_for_mode,
    report_one_vs_one_winner,
)
from ..lol import generate_lol_bracket
from ..presentation import bracket_embed, bracket_to_text, chunk_text, enrollment_embed
from ..storage import TournamentStore
from ..views import EnrollmentView, MatchResultView


class TournamentCog(commands.Cog):
    tournament = app_commands.Group(
        name="tournament",
        description="Create and manage 7amidelmath tournaments.",
    )

    def __init__(self, bot: commands.Bot, store: TournamentStore) -> None:
        self.bot = bot
        self.store = store

    @tournament.command(name="create", description="Post a tournament enrollment message.")
    @app_commands.describe(
        mode="Choose 1v1 for solo matches or 5v5 for team matches.",
        name="Tournament name shown on embeds.",
        max_players="Optional enrollment cap.",
        mute_on_enroll="Voice-mute players who enroll while they are in a voice channel.",
    )
    @app_commands.choices(
        mode=[
            app_commands.Choice(name="1 vs 1", value="1v1"),
            app_commands.Choice(name="5 vs 5", value="5v5"),
        ]
    )
    async def create(
        self,
        interaction: discord.Interaction,
        mode: app_commands.Choice[str],
        name: str = "Random Tournament",
        max_players: int | None = None,
        mute_on_enroll: bool = False,
    ) -> None:
        if interaction.guild_id is None or interaction.channel_id is None:
            await interaction.response.send_message(
                "Tournaments can only be created inside a Discord server.",
                ephemeral=True,
            )
            return

        clean_name = name.strip()[:80] or "Random Tournament"
        min_players = minimum_players_for_mode(mode.value)
        if max_players is not None and max_players < min_players:
            await interaction.response.send_message(
                f"{mode.name} needs at least {min_players} players.",
                ephemeral=True,
            )
            return

        tournament_id = self.store.create_tournament(
            guild_id=interaction.guild_id,
            channel_id=interaction.channel_id,
            creator_id=interaction.user.id,
            name=clean_name,
            mode=mode.value,
            max_players=max_players,
            mute_on_enroll=mute_on_enroll,
        )
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message(
                "Something went wrong while creating the tournament.",
                ephemeral=True,
            )
            return

        await interaction.response.send_message(
            embed=enrollment_embed(tournament, []),
            view=EnrollmentView(self.store),
        )
        message = await interaction.original_response()
        self.store.set_message_id(tournament_id, message.id)

    @tournament.command(name="list", description="List recent tournaments in this server.")
    @app_commands.describe(status="Which tournament status to show.")
    @app_commands.choices(
        status=[
            app_commands.Choice(name="Open", value="open"),
            app_commands.Choice(name="Started", value="started"),
            app_commands.Choice(name="Cancelled", value="cancelled"),
            app_commands.Choice(name="All", value="all"),
        ]
    )
    async def list(
        self,
        interaction: discord.Interaction,
        status: app_commands.Choice[str] | None = None,
    ) -> None:
        if interaction.guild_id is None:
            await interaction.response.send_message(
                "Tournament lists are only available inside a Discord server.",
                ephemeral=True,
            )
            return

        selected_status = status.value if status else "open"
        records = self.store.list_tournaments(
            guild_id=interaction.guild_id,
            status=None if selected_status == "all" else selected_status,
            limit=10,
        )
        if not records:
            await interaction.response.send_message("No tournaments found.", ephemeral=True)
            return

        lines = []
        for record in records:
            count = self.store.participant_count(record["id"])
            cap = f"/{record['max_players']}" if record.get("max_players") else ""
            lines.append(
                f"`#{record['id']}` **{record['name']}** - "
                f"{record['mode']} - {record['status']} - {count}{cap} enrolled"
            )

        await interaction.response.send_message("\n".join(lines), ephemeral=True)

    @tournament.command(name="start", description="Close enrollment and generate a random bracket.")
    @app_commands.describe(
        tournament_id="Tournament ID. Leave as 0 to use the latest open tournament in this channel."
    )
    async def start(self, interaction: discord.Interaction, tournament_id: int = 0) -> None:
        tournament = self._resolve_tournament(interaction, tournament_id)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find that tournament.",
                ephemeral=True,
            )
            return

        if not self._can_manage(interaction, tournament):
            await interaction.response.send_message(
                "Only the tournament creator or a server manager can start it.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "open":
            await interaction.response.send_message(
                "Only open tournaments can be started.",
                ephemeral=True,
            )
            return

        participants = self._participants_for_start(tournament)
        try:
            bracket = self._generate_bracket(tournament, participants)
        except NotEnoughPlayersError as error:
            await interaction.response.send_message(str(error), ephemeral=True)
            return

        await interaction.response.defer(thinking=True)
        self.store.start_tournament(tournament["id"], bracket)
        tournament = self.store.get_tournament(tournament["id"]) or tournament
        await self._edit_enrollment_message(tournament, remove_buttons=True)
        await self._send_bracket(interaction, tournament, bracket)
        await self._create_lol_match_threads(interaction, tournament, bracket)

    @tournament.command(name="bracket", description="Show an already-generated bracket.")
    @app_commands.describe(tournament_id="Tournament ID to display.")
    async def bracket(self, interaction: discord.Interaction, tournament_id: int) -> None:
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find that tournament.",
                ephemeral=True,
            )
            return

        bracket = self.store.get_bracket(tournament_id)
        if bracket is None:
            await interaction.response.send_message(
                "That tournament does not have a generated bracket yet.",
                ephemeral=True,
            )
            return

        await interaction.response.defer(thinking=True)
        await self._send_bracket(interaction, tournament, bracket)

    @tournament.command(name="winner", description="Report a 1v1 match winner and advance the bracket.")
    @app_commands.describe(
        tournament_id="Tournament ID.",
        match_number="Match number in the current round.",
        winner="The player who won the match.",
        round_number="Optional round number. Leave as 0 for the latest round.",
    )
    async def winner(
        self,
        interaction: discord.Interaction,
        tournament_id: int,
        match_number: int,
        winner: discord.Member,
        round_number: int = 0,
    ) -> None:
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find that tournament.",
                ephemeral=True,
            )
            return

        if not self._can_manage(interaction, tournament):
            await interaction.response.send_message(
                "Only the tournament creator or a server manager can report winners.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "started":
            await interaction.response.send_message(
                "Start the tournament before reporting winners.",
                ephemeral=True,
            )
            return

        bracket = self.store.get_bracket(tournament_id)
        if bracket is None:
            await interaction.response.send_message(
                "That tournament does not have a generated bracket yet.",
                ephemeral=True,
            )
            return

        try:
            result = report_one_vs_one_winner(
                bracket,
                match_number=match_number,
                winner_user_id=winner.id,
                round_number=round_number or None,
            )
        except BracketProgressionError as error:
            await interaction.response.send_message(str(error), ephemeral=True)
            return

        await interaction.response.defer(thinking=True)
        self.store.update_bracket(tournament_id, result["bracket"])

        message = (
            f"Recorded <@{winner.id}> as winner of Round {result['round_number']} "
            f"Match {result['match_number']}."
        )
        if result["completed"]:
            champion = result["bracket"]["champion"]
            message += f"\nChampion: <@{champion['user_id']}>."
        elif result["advanced"]:
            message += f"\nRound {result['next_round_number']} is ready."
        else:
            message += "\nWaiting for the rest of this round's winners."

        await interaction.followup.send(message)
        await self._send_bracket(interaction, tournament, result["bracket"])

    @tournament.command(name="cancel", description="Cancel an open tournament.")
    @app_commands.describe(tournament_id="Tournament ID to cancel.")
    async def cancel(self, interaction: discord.Interaction, tournament_id: int) -> None:
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find that tournament.",
                ephemeral=True,
            )
            return

        if not self._can_manage(interaction, tournament):
            await interaction.response.send_message(
                "Only the tournament creator or a server manager can cancel it.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "open":
            await interaction.response.send_message(
                "Only open tournaments can be cancelled.",
                ephemeral=True,
            )
            return

        await interaction.response.defer(thinking=True)
        self.store.cancel_tournament(tournament_id)
        tournament = self.store.get_tournament(tournament_id) or tournament
        await self._edit_enrollment_message(tournament, remove_buttons=True)
        await interaction.followup.send(f"Cancelled tournament `#{tournament_id}`.")

    def _resolve_tournament(
        self,
        interaction: discord.Interaction,
        tournament_id: int,
    ) -> dict[str, Any] | None:
        if tournament_id:
            return self.store.get_tournament(tournament_id)

        if interaction.guild_id is None or interaction.channel_id is None:
            return None
        return self.store.latest_open_tournament(
            guild_id=interaction.guild_id,
            channel_id=interaction.channel_id,
        )

    def _can_manage(self, interaction: discord.Interaction, tournament: dict[str, Any]) -> bool:
        if interaction.user.id == tournament["creator_id"]:
            return True
        permissions = getattr(interaction.user, "guild_permissions", None)
        return bool(permissions and permissions.manage_guild)

    def _participants_for_start(self, tournament: dict[str, Any]) -> list[dict[str, Any]]:
        if tournament.get("game") != "league_of_legends":
            return self.store.list_participants(tournament["id"])

        participants = self.store.list_lol_participants(tournament["id"])
        if tournament.get("check_in_required"):
            participants = [participant for participant in participants if participant.get("checked_in")]
        return participants

    def _generate_bracket(
        self,
        tournament: dict[str, Any],
        participants: list[dict[str, Any]],
    ) -> dict[str, Any]:
        if tournament.get("game") == "league_of_legends":
            return generate_lol_bracket(mode=tournament["mode"], participants=participants)
        return generate_bracket(mode=tournament["mode"], participants=participants)

    async def _send_bracket(
        self,
        interaction: discord.Interaction,
        tournament: dict[str, Any],
        bracket: dict[str, Any],
    ) -> None:
        chunks = chunk_text(bracket_to_text(bracket))
        total_pages = len(chunks)
        for index, chunk in enumerate(chunks, start=1):
            await interaction.followup.send(
                embed=bracket_embed(
                    tournament,
                    chunk,
                    page=index,
                    total_pages=total_pages,
                )
            )

    async def _edit_enrollment_message(
        self,
        tournament: dict[str, Any],
        *,
        remove_buttons: bool,
    ) -> None:
        message_id = tournament.get("message_id")
        if not message_id:
            return

        try:
            channel = self.bot.get_channel(tournament["channel_id"])
            if channel is None:
                channel = await self.bot.fetch_channel(tournament["channel_id"])
            message = await channel.fetch_message(message_id)
            participants = self.store.list_participants(tournament["id"])
            if tournament.get("game") == "league_of_legends":
                participants = self.store.list_lol_participants(tournament["id"])
            await message.edit(
                embed=enrollment_embed(tournament, participants),
                view=None if remove_buttons else EnrollmentView(self.store),
            )
        except (discord.DiscordException, AttributeError):
            return

    async def _create_lol_match_threads(
        self,
        interaction: discord.Interaction,
        tournament: dict[str, Any],
        bracket: dict[str, Any],
    ) -> None:
        if tournament.get("game") != "league_of_legends" or interaction.channel is None:
            return

        round_one = bracket["rounds"][0]
        for match in round_one["matches"]:
            team_a_name, team_b_name = self._match_names(match)
            thread = None
            try:
                if hasattr(interaction.channel, "create_thread"):
                    thread = await interaction.channel.create_thread(
                        name=f"T{tournament['id']} Match {match['match_number']}: {team_a_name} vs {team_b_name}",
                        type=discord.ChannelType.public_thread,
                    )
            except discord.DiscordException:
                thread = None

            target = thread or interaction.channel
            message = await target.send(
                embed=self._match_embed(tournament, match),
                view=MatchResultView(self.store),
            )
            self.store.register_match_message(
                message_id=message.id,
                tournament_id=tournament["id"],
                match_number=match["match_number"],
                thread_id=thread.id if thread else None,
                team_a_name=team_a_name,
                team_b_name=team_b_name,
            )

    def _match_embed(self, tournament: dict[str, Any], match: dict[str, Any]) -> discord.Embed:
        team_a_name, team_b_name = self._match_names(match)
        embed = discord.Embed(
            title=f"LoL Match {match['match_number']}",
            description=(
                f"**{team_a_name}** vs **{team_b_name}**\n"
                "Report the winner with the buttons below. A second player can confirm it."
            ),
            color=discord.Color.blue(),
        )
        embed.add_field(name="Tournament", value=f"#{tournament['id']} {tournament['name']}", inline=False)
        embed.add_field(name=team_a_name, value=self._team_roster(match, "team_a"), inline=True)
        embed.add_field(name=team_b_name, value=self._team_roster(match, "team_b"), inline=True)
        embed.set_footer(text="Use Dispute if the reported result is wrong.")
        return embed

    def _match_names(self, match: dict[str, Any]) -> tuple[str, str]:
        if "team_a" in match:
            return match["team_a"]["name"], match["team_b"]["name"]
        return self._player_name(match["player_a"]), self._player_name(match["player_b"])

    def _team_roster(self, match: dict[str, Any], key: str) -> str:
        if key in match and "players" in match[key]:
            return "\n".join(f"<@{player['user_id']}>" for player in match[key]["players"])
        player_key = "player_a" if key == "team_a" else "player_b"
        if player_key in match:
            return f"<@{match[player_key]['user_id']}>"
        return "Unknown"

    def _player_name(self, player: dict[str, Any]) -> str:
        riot_name = player.get("riot_name")
        tag_line = player.get("tag_line")
        if riot_name and tag_line:
            return f"{riot_name}#{tag_line}"
        return player.get("display_name") or f"Player {player['user_id']}"
