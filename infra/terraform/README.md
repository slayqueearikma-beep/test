# Terraform hosting for 7amidelmath

This module deploys the bot to Azure Container Apps on the consumption profile.
It is designed for a low-budget Discord bot:

- 1 tiny always-on container replica by default
- 0.25 CPU and 0.5 GiB memory
- No public ingress
- Basic Azure Container Registry
- 1 GiB Azure Files share mounted at `/app/data` for the SQLite database
- Log Analytics retention set to 30 days

## Prerequisites

- Terraform 1.5 or newer
- Azure CLI
- An Azure subscription
- A Discord bot token

Log in first:

```bash
az login
az account set --subscription "<subscription-id-or-name>"
```

## Deploy

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

```hcl
discord_token = "your-discord-bot-token"
```

Then apply:

```bash
terraform init
terraform apply
```

Terraform creates the registry, builds the Docker image with `az acr build`,
pushes it to the registry, and starts the Container App.

## Updating the bot

After changing Python code or `requirements.txt`, run:

```bash
cd infra/terraform
terraform apply
```

The module hashes the bot source files and rebuilds the image when they change.

## Cost notes

The bot stays connected to Discord, so `min_replicas` defaults to `1`. Setting it
to `0` can reduce compute cost, but the bot will go offline when Azure scales it
down. Keep `max_replicas` at `1` to avoid duplicate Discord gateway sessions.

Terraform state will contain sensitive values for the Container Apps secret.
Use an encrypted remote backend for real deployments and never commit
`terraform.tfstate` or `terraform.tfvars`.
