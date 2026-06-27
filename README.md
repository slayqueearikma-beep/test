# Superior RPG Minecraft Azure Terraform

This repository contains a production-ready Terraform project for hosting a public Superior RPG Minecraft server directly on Microsoft Azure with Ubuntu, Java 21, and systemd.

See the complete implementation and deployment guide in [`terraform/README.md`](terraform/README.md).

## Start and stop the lab

After deployment, you can start or deallocate the Azure VM with helper scripts:

```bash
python scripts/start-lab.py
python scripts/stop-lab.py
```

`stop-lab.py` uses Azure VM deallocation, which stops VM compute billing while keeping disks, IP, Key Vault, and storage.

## Discord start/stop bot

Optional Discord bot tooling is available in [`discord-bot/`](discord-bot/). It provides `/startlab`, `/stoplab`, and `/statuslab` commands for allowed Discord user IDs.
