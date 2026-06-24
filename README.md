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
- Styled PNG bracket images plus text backup output.
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

## Low-budget cloud hosting with Terraform

This repo includes Terraform for hosting the bot on Azure Container Apps using a
small consumption-profile container:

- 0.25 CPU / 0.5 GiB memory by default
- 1 always-on replica so the Discord gateway connection stays online
- no public ingress
- Basic Azure Container Registry
- a 1 GiB Azure Files share mounted at `/app/data` for the SQLite database

Deploy it:

```bash
az login
az account set --subscription "<subscription-id-or-name>"
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
discord_token = "your-discord-bot-token"
```

Then run:

```bash
terraform init
terraform apply
```

Terraform builds the Docker image with `az acr build`, pushes it to Azure
Container Registry, and deploys it to Container Apps. See
[`infra/terraform/README.md`](infra/terraform/README.md) for update and cost
notes.

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

When a tournament starts, the bot sends a styled PNG bracket image in Discord.
The same message also includes the text bracket so people can copy mentions or
read it if image previews are disabled.

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
