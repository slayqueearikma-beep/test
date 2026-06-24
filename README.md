# 7amidelmath Discord Tournament Bot

7amidelmath is a Discord bot for quick community tournaments. It posts an
enrollment message with buttons, collects everyone who clicks **Enroll**, and
generates randomized brackets for:

- 1 vs 1 solo tournaments
- 5 vs 5 team tournaments

It also includes small activity commands for waiting rooms: random challenges,
coin flips, dice rolls, option picking, and an enrollment leaderboard.

## Features

- Slash commands for tournament creation, listing, starting, cancellation, and
  bracket display.
- Persistent SQLite storage for tournaments, enrollment messages, participants,
  and generated brackets.
- Restart-safe enrollment buttons using stable Discord component IDs.
- Random seeding for fair first-round matchups.
- 5 vs 5 team generation with reserves when the player count is not a multiple
  of five.
- Rotating Discord presence activities.

## Requirements

- Python 3.10 or newer
- A Discord application and bot token

## Discord setup

1. Open the Discord Developer Portal.
2. Create an application named `7amidelmath`.
3. Add a bot to the application and copy the bot token.
4. Invite the bot to your server with these scopes:
   - `bot`
   - `applications.commands`
5. Recommended bot permissions:
   - Send Messages
   - Embed Links
   - Read Message History
   - Use Slash Commands

The visible bot name is controlled in the Discord Developer Portal. The code is
configured to run the 7amidelmath tournament features.

## Local setup

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
cp .env.example .env
```

Edit `.env`:

```env
DISCORD_TOKEN=your-discord-bot-token
GUILD_ID=your-test-server-id
```

`GUILD_ID` is optional, but it makes slash-command updates appear much faster
while developing. Remove it when you want global command sync.

## Run the bot

```bash
python3 bot.py
```

Tournament data is stored at `data/tournaments.db` by default. You can override
that with `DATABASE_PATH` in `.env`.

## Commands

### Tournament commands

- `/tournament create mode name max_players`
  - Posts a message with **Enroll** and **Withdraw** buttons.
  - `mode` can be `1 vs 1` or `5 vs 5`.
  - `max_players` is optional.
- `/tournament list status`
  - Lists recent tournaments in the server.
- `/tournament start tournament_id`
  - Closes enrollment and generates the random bracket.
  - Use `0` or leave blank to start the newest open tournament in the channel.
  - Only the creator or someone with Manage Server can start it.
- `/tournament bracket tournament_id`
  - Shows a previously generated bracket.
- `/tournament cancel tournament_id`
  - Cancels an open tournament.
  - Only the creator or someone with Manage Server can cancel it.

### Activity commands

- `/activity challenge` - suggests a fun tournament activity.
- `/activity coinflip` - flips a coin.
- `/activity roll sides` - rolls a die.
- `/activity pick options` - picks from comma-separated options.
- `/activity leaderboard` - shows the most active enrolled players.

## Bracket behavior

### 1 vs 1

Players are shuffled and paired into first-round matches. If there is an odd
number of players, one player receives a bye.

### 5 vs 5

Players are shuffled into teams of five. Teams are paired into first-round
matches. If there is an odd number of teams, one team receives a bye. Extra
players who cannot fill a full team are listed as reserves.

## Tests

```bash
python3 -m pytest
```
