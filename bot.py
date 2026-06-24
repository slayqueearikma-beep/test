from __future__ import annotations

import itertools
import logging

import discord
from discord.ext import commands, tasks
from dotenv import load_dotenv

from sevenamidelmath.cogs.activities import ActivitiesCog
from sevenamidelmath.cogs.tournament import TournamentCog
from sevenamidelmath.config import Settings
from sevenamidelmath.storage import TournamentStore
from sevenamidelmath.views import EnrollmentView


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)


class SevenAmidelMathBot(commands.Bot):
    def __init__(self, settings: Settings) -> None:
        intents = discord.Intents.default()
        super().__init__(
            command_prefix="!",
            intents=intents,
            description="7amidelmath tournament bot",
        )
        self.settings = settings
        self.store = TournamentStore(settings.database_path)
        self._presence_cycle = itertools.cycle(
            [
                discord.Game("random 1v1 brackets"),
                discord.Game("5v5 team enrollments"),
                discord.Game("/tournament create"),
                discord.Game("fair shuffled matchups"),
            ]
        )

    async def setup_hook(self) -> None:
        self.store.setup()
        self.add_view(EnrollmentView(self.store))
        await self.add_cog(TournamentCog(self, self.store))
        await self.add_cog(ActivitiesCog(self, self.store))

        if self.settings.auto_sync_commands:
            if self.settings.guild_id:
                guild = discord.Object(id=self.settings.guild_id)
                self.tree.copy_global_to(guild=guild)
                await self.tree.sync(guild=guild)
                logging.info("Synced slash commands to guild %s", self.settings.guild_id)
            else:
                await self.tree.sync()
                logging.info("Synced global slash commands")

    async def on_ready(self) -> None:
        if not self.rotate_presence.is_running():
            self.rotate_presence.start()
        logging.info("Logged in as %s (ID: %s)", self.user, self.user.id if self.user else "unknown")

    async def close(self) -> None:
        self.store.close()
        await super().close()

    @tasks.loop(minutes=10)
    async def rotate_presence(self) -> None:
        await self.change_presence(activity=next(self._presence_cycle))

    @rotate_presence.before_loop
    async def before_rotate_presence(self) -> None:
        await self.wait_until_ready()


def main() -> None:
    load_dotenv()
    settings = Settings.from_environment()
    bot = SevenAmidelMathBot(settings)
    bot.run(settings.discord_token)


if __name__ == "__main__":
    main()
