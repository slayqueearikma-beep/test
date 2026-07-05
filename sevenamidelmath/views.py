from __future__ import annotations

from typing import Any

import discord

from .lol import is_rank_allowed
from .presentation import enrollment_embed
from .storage import TournamentStore


class EnrollmentView(discord.ui.View):
    def __init__(self, store: TournamentStore) -> None:
        super().__init__(timeout=None)
        self.store = store

    @discord.ui.button(
        label="Enroll",
        style=discord.ButtonStyle.success,
        custom_id="7amidelmath:enroll",
    )
    async def enroll(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["EnrollmentView"],
    ) -> None:
        tournament = self._tournament_for_interaction(interaction)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find a tournament attached to this message.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "open":
            await interaction.response.send_message(
                "Enrollment is closed for this tournament.",
                ephemeral=True,
            )
            return

        max_players = tournament.get("max_players")
        if max_players and self.store.participant_count(tournament["id"]) >= max_players:
            await interaction.response.send_message(
                "This tournament is already full.",
                ephemeral=True,
            )
            return

        if not await self._eligible_for_lol_tournament(interaction, tournament):
            return

        display_name = getattr(interaction.user, "display_name", interaction.user.name)
        added = self.store.add_participant(tournament["id"], interaction.user.id, display_name)
        await self._refresh_message(interaction, tournament["id"])

        if added:
            message = f"You are enrolled in **{tournament['name']}**."
            if tournament.get("mute_on_enroll"):
                message += " " + await self._mute_member_in_voice(interaction, tournament)
        else:
            message = f"You were already enrolled in **{tournament['name']}**."
        await interaction.followup.send(message, ephemeral=True)

    @discord.ui.button(
        label="Check In",
        style=discord.ButtonStyle.primary,
        custom_id="7amidelmath:checkin",
    )
    async def check_in(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["EnrollmentView"],
    ) -> None:
        tournament = self._tournament_for_interaction(interaction)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find a tournament attached to this message.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "open":
            await interaction.response.send_message(
                "Check-in is closed for this tournament.",
                ephemeral=True,
            )
            return

        if not tournament.get("check_in_required"):
            await interaction.response.send_message(
                "This tournament does not require check-in.",
                ephemeral=True,
            )
            return

        checked_in = self.store.set_checked_in(tournament["id"], interaction.user.id)
        await self._refresh_message(interaction, tournament["id"])
        if checked_in:
            await interaction.followup.send("You are checked in for this tournament.", ephemeral=True)
        else:
            await interaction.followup.send(
                "Enroll first, then check in for this tournament.",
                ephemeral=True,
            )

    @discord.ui.button(
        label="Withdraw",
        style=discord.ButtonStyle.secondary,
        custom_id="7amidelmath:withdraw",
    )
    async def withdraw(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["EnrollmentView"],
    ) -> None:
        tournament = self._tournament_for_interaction(interaction)
        if tournament is None:
            await interaction.response.send_message(
                "I could not find a tournament attached to this message.",
                ephemeral=True,
            )
            return

        if tournament["status"] != "open":
            await interaction.response.send_message(
                "This tournament has already started or was cancelled.",
                ephemeral=True,
            )
            return

        removed = self.store.remove_participant(tournament["id"], interaction.user.id)
        await self._refresh_message(interaction, tournament["id"])

        if removed:
            message = f"You withdrew from **{tournament['name']}**."
        else:
            message = "You were not enrolled in this tournament."
        await interaction.followup.send(message, ephemeral=True)

    def _tournament_for_interaction(
        self,
        interaction: discord.Interaction,
    ) -> dict[str, Any] | None:
        if interaction.message is None:
            return None
        return self.store.get_tournament_by_message(interaction.message.id)

    async def _refresh_message(self, interaction: discord.Interaction, tournament_id: int) -> None:
        await interaction.response.defer(ephemeral=True, thinking=False)
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None or interaction.message is None:
            return
        participants = self.store.list_participants(tournament_id)
        if tournament.get("game") == "league_of_legends":
            participants = self.store.list_lol_participants(tournament_id)
        await interaction.message.edit(embed=enrollment_embed(tournament, participants), view=self)

    async def _eligible_for_lol_tournament(
        self,
        interaction: discord.Interaction,
        tournament: dict[str, Any],
    ) -> bool:
        if tournament.get("game") != "league_of_legends":
            return True

        if interaction.guild_id is None:
            await interaction.response.send_message(
                "League tournaments can only be joined inside a Discord server.",
                ephemeral=True,
            )
            return False

        profile = self.store.get_lol_profile(
            guild_id=interaction.guild_id,
            user_id=interaction.user.id,
        )
        if profile is None:
            await interaction.response.send_message(
                "Link your Riot account first with `/lol link`, then enroll.",
                ephemeral=True,
            )
            return False

        region = tournament.get("lol_region")
        if region and profile.get("region") != region:
            await interaction.response.send_message(
                f"This tournament is for {region}; your profile is set to {profile.get('region')}.",
                ephemeral=True,
            )
            return False

        if not is_rank_allowed(profile.get("rank"), tournament.get("rank_min"), tournament.get("rank_max")):
            await interaction.response.send_message(
                "Your linked rank does not match this tournament's rank limits.",
                ephemeral=True,
            )
            return False

        min_level = tournament.get("min_account_level")
        account_level = profile.get("account_level")
        if min_level and (account_level is None or account_level < min_level):
            await interaction.response.send_message(
                f"This tournament requires account level {min_level}+.",
                ephemeral=True,
            )
            return False

        return True

    async def _mute_member_in_voice(
        self,
        interaction: discord.Interaction,
        tournament: dict[str, Any],
    ) -> str:
        member = interaction.user if isinstance(interaction.user, discord.Member) else None
        if member is None and interaction.guild is not None:
            member = interaction.guild.get_member(interaction.user.id)

        if member is None:
            return "I could not find your server member record to voice-mute you."

        if member.voice is None or member.voice.channel is None:
            return "You are not in a voice channel, so no voice mute was applied."

        try:
            await member.edit(
                mute=True,
                reason=f"7amidelmath tournament #{tournament['id']} mute on enroll",
            )
        except discord.Forbidden:
            return "I tried to voice-mute you, but I need the **Mute Members** permission."
        except discord.HTTPException:
            return "I tried to voice-mute you, but Discord rejected the request."

        return "You were voice-muted for this tournament."


class MatchResultView(discord.ui.View):
    def __init__(self, store: TournamentStore) -> None:
        super().__init__(timeout=None)
        self.store = store

    @discord.ui.button(
        label="Team A Won",
        style=discord.ButtonStyle.success,
        custom_id="7amidelmath:result:team_a",
    )
    async def team_a_won(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["MatchResultView"],
    ) -> None:
        await self._record_result(interaction, "team_a")

    @discord.ui.button(
        label="Team B Won",
        style=discord.ButtonStyle.success,
        custom_id="7amidelmath:result:team_b",
    )
    async def team_b_won(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["MatchResultView"],
    ) -> None:
        await self._record_result(interaction, "team_b")

    @discord.ui.button(
        label="Dispute",
        style=discord.ButtonStyle.danger,
        custom_id="7amidelmath:result:dispute",
    )
    async def dispute(
        self,
        interaction: discord.Interaction,
        _: discord.ui.Button["MatchResultView"],
    ) -> None:
        if interaction.message is None:
            await interaction.response.send_message("I could not find this match message.", ephemeral=True)
            return
        match = self.store.get_match_message(interaction.message.id)
        if match is None:
            await interaction.response.send_message("I could not find this match record.", ephemeral=True)
            return
        self.store.mark_match_disputed(
            message_id=interaction.message.id,
            reporter_id=interaction.user.id,
        )
        await interaction.response.send_message(
            "Result disputed. An admin should review this match.",
        )

    async def _record_result(self, interaction: discord.Interaction, winner_key: str) -> None:
        if interaction.message is None:
            await interaction.response.send_message("I could not find this match message.", ephemeral=True)
            return

        result = self.store.record_match_result(
            message_id=interaction.message.id,
            winner_key=winner_key,
            reporter_id=interaction.user.id,
        )
        if result is None:
            await interaction.response.send_message("I could not find this match record.", ephemeral=True)
            return

        winner_name = result["team_a_name"] if winner_key == "team_a" else result["team_b_name"]
        status = result["result_status"]
        if status == "reported":
            message = f"{winner_name} was reported as winner. Another player should confirm."
        elif status == "confirmed":
            message = f"{winner_name} is confirmed as winner."
        elif status == "needs_second_confirmation":
            message = "You already reported this result. Another player must confirm it."
        elif status == "already_confirmed":
            message = "This match result is already confirmed."
        else:
            message = "Conflicting result reported. An admin should review this match."
        await interaction.response.send_message(message)
