from __future__ import annotations

import discord

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

        display_name = getattr(interaction.user, "display_name", interaction.user.name)
        added = self.store.add_participant(tournament["id"], interaction.user.id, display_name)
        await self._refresh_message(interaction, tournament["id"])

        if added:
            message = f"You are enrolled in **{tournament['name']}**."
        else:
            message = f"You were already enrolled in **{tournament['name']}**."
        await interaction.followup.send(message, ephemeral=True)

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
    ) -> dict | None:
        if interaction.message is None:
            return None
        return self.store.get_tournament_by_message(interaction.message.id)

    async def _refresh_message(self, interaction: discord.Interaction, tournament_id: int) -> None:
        await interaction.response.defer(ephemeral=True, thinking=False)
        tournament = self.store.get_tournament(tournament_id)
        if tournament is None or interaction.message is None:
            return
        participants = self.store.list_participants(tournament_id)
        await interaction.message.edit(embed=enrollment_embed(tournament, participants), view=self)
