# Discord Lab Bot

Optional Discord bot for starting, stopping, and checking the Azure Minecraft VM.

Commands:

- `/startlab` - starts the VM
- `/stoplab` - deallocates the VM to stop compute billing
- `/statuslab` - shows VM power state

## Requirements

- Python 3.10+
- Azure CLI installed on the machine running the bot
- `az login` completed on that machine
- Discord bot token
- Your Discord numeric user ID

The bot must keep running somewhere to receive Discord commands. It can run on your PC while your PC is on, or on a small always-on host.

## Create the Discord bot

1. Go to <https://discord.com/developers/applications>.
2. Create a new application.
3. Open **Bot**.
4. Create/reset the token and copy it.
5. Open **OAuth2 > URL Generator**.
6. Select scopes:
   - `bot`
   - `applications.commands`
7. Select bot permissions:
   - no special permissions are required for slash commands
8. Open the generated URL and invite the bot to your server.

## Configure

From this folder:

```bash
cp .env.example .env
```

Edit `.env`:

```text
DISCORD_TOKEN=your_bot_token
DISCORD_ALLOWED_USER_IDS=your_discord_user_id,friend_discord_user_id
AZURE_RESOURCE_GROUP=rg-superior-rpg-prod
AZURE_VM_NAME=vm-superior-rpg-prod
MINECRAFT_SERVER_ADDRESS=51.12.88.101:25565
```

To get a Discord user ID:

1. Discord settings
2. Advanced
3. Enable Developer Mode
4. Right-click user
5. Copy User ID

Never commit `.env`.

## Install and run

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
az login
python bot.py
```

PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
az login
python bot.py
```

## Security notes

- Only IDs in `DISCORD_ALLOWED_USER_IDS` can use the commands.
- Do not share the bot token.
- Do not commit `.env`.
- The bot host must have Azure permission to start/deallocate the VM.
- If the bot runs on your PC, friends cannot use it while your PC is off.

## Direct Azure commands used

Start:

```bash
az vm start --resource-group rg-superior-rpg-prod --name vm-superior-rpg-prod
```

Stop billing:

```bash
az vm deallocate --resource-group rg-superior-rpg-prod --name vm-superior-rpg-prod
```
