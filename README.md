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
- League of Legends profile linking, role/rank tracking, check-ins, balanced
  5v5 teams, match threads, and result buttons.
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
   - Mute Members, if you want to use the optional voice mute on enroll power

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
  - `mute_on_enroll` is optional. When enabled, players who click **Enroll**
    while they are in a voice channel are server-muted in voice.
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

### League of Legends commands

- `/lol link riot_name tag_line region rank role account_level`
  - Links a Riot ID, rank, region, and preferred role to your Discord account.
  - This is manual/self-entered today, so no Riot API key is required.
- `/lol profile member`
  - Shows a linked Riot profile.
- `/lol role role`
  - Updates your preferred role: Top, Jungle, Mid, ADC, Support, or Fill.
- `/lol create mode name region map_name rank_min rank_max min_account_level max_players check_in_required mute_on_enroll`
  - Posts a League-specific enrollment message with the green **Enroll** button.
  - Enrolling players must have `/lol link` set up first.
  - Optional region and rank limits are enforced at enrollment.
  - Optional account-level limits can help discourage obvious smurf accounts.
- `/lol checkin tournament_id`
  - Checks you in for a League tournament that requires check-in.
  - The enrollment message also has a **Check In** button.
- `/lol checkins tournament_id`
  - Shows checked-in count.
- `/lol leaderboard`
  - Shows linked League players ordered by tournament activity.
- `/lol player member`
  - Shows a quick player scouting card.
- `/lol result tournament_id match_number winner`
  - Manually reports or confirms a match result.
- `/lol rules`
  - Shows recommended League tournament rules.
- `/lol draft team_a team_b`
  - Coinflips side selection and gives a simple pick/ban helper prompt.

## League of Legends workflow

1. Players link profiles:

   ```text
   /lol link riot_name: Faker tag_line: KR1 region: KR rank: Challenger role: Mid
   ```

2. Admin creates a LoL lobby:

   ```text
   /lol create mode: 5 vs 5 name: Friday Rift Cup region: EUW check_in_required: true
   ```

3. Players click **Enroll** on the visible channel message.
4. Players click **Check In** before start, if check-in is required.
5. Admin starts the tournament:

   ```text
   /tournament start tournament_id: 1
   ```

6. The bot generates rank/role-balanced teams for 5v5 and posts the bracket.
7. For League tournaments, the bot also creates match threads when possible.
   Each match thread contains:
   - team rosters
   - result buttons
   - dispute button
8. A player reports the winner. A second player can click the same winner to
   confirm it. If players disagree, click **Dispute** for admin review.

## Bracket behavior

### 1 vs 1

Players are shuffled and paired into first-round matches. If there is an odd
number of players, one player receives a bye.

### 5 vs 5

Players are shuffled into teams of five. Teams are paired into first-round
matches. If there is an odd number of teams, one team receives a bye. Extra
players who cannot fill a full team are listed as reserves.

### League 5 vs 5

League 5v5 tournaments use Riot profile data from `/lol link`. The bot tries to:

- keep teams near the same average rank
- spread Top, Jungle, Mid, ADC, and Support across teams
- use Fill players where needed
- keep extra players as reserves

## Optional voice mute on enroll

When creating a tournament, set `mute_on_enroll` to `true` if you want the bot to
voice-mute players as soon as they click **Enroll**. This only affects players
who are already connected to a voice channel when they enroll.

The bot needs the Discord **Mute Members** permission for this. It does not
automatically unmute players on withdraw, because that could override a manual
moderation mute.

## Tests

```bash
python3 -m pytest
```
