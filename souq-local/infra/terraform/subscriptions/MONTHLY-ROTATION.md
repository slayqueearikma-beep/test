# Monthly subscription rotation (sub1 → sub2 → sub3 …)

Use **one subscription at a time**. When credits hit **$0**, move to the next subscription **with all your data** — users, sellers, reviews, and product images.

## One command (recommended)

**Windows:**

```powershell
cd souq-local\infra\terraform

# Month 1 — first deploy
.\scripts\switch-subscription.ps1 -Sub 1

# When sub1 budget is $0 — move everything to sub2
.\scripts\rotate-subscription.ps1 -FromSub 1 -ToSub 2
```

**Bash:**

```bash
./scripts/switch-subscription.sh 1
./scripts/rotate-subscription.sh 1 2
```

`rotate-subscription` does:

1. **Backup** PostgreSQL + blob images from sub1 → `backups/sub1/`
2. **Deploy** sub2 (new Azure stack)
3. **Restore** database + images onto sub2
4. **Destroy** sub1 (optional prompt) to stop billing

Your app continues with the **same accounts and listings** — not from zero.

## One-time setup

```bash
az login
az account list --output table
```

```bash
cp subscriptions/sub1.tfvars.example subscriptions/sub1.tfvars
# Edit: subscription_id, postgres_admin_password, jwt_secret_key
```

When you rotate to sub2, the script creates `sub2.tfvars` and **copies `jwt_secret_key` from sub1** so users stay logged in.

## What gets migrated

| Data | How |
|------|-----|
| Users, sellers, reviews, listings | PostgreSQL `pg_dump` / `pg_restore` |
| Product/seller images | Azure Blob batch download → upload |
| Login sessions | Same `jwt_secret_key` copied to new tfvars |

Backups are stored locally under `infra/terraform/backups/subN/` (not committed to git).

## Requirements

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- **pg_dump / pg_restore** — or **Docker** (scripts use `postgres:16` image automatically)

## Manual steps (if you prefer)

```powershell
# 1. Backup
.\scripts\backup-subscription-data.ps1 -Sub 1

# 2. Deploy new subscription
.\scripts\switch-subscription.ps1 -Sub 2

# 3. Restore data
.\scripts\restore-subscription-data.ps1 -Sub 2 -FromSub 1

# 4. Stop billing on old sub
.\scripts\destroy-subscription.ps1 -Sub 1
```

## After rotation — mobile app

The API **hostname** changes (new Container App). Rebuild the app:

```powershell
$api = terraform output -state=terraform-sub2.tfstate -raw api_url
flutter build apk --dart-define=PRODUCTION=true --dart-define=API_BASE_URL=$api
```

Users keep their accounts; they only need the updated app if the API URL changed.

## Month 3, 4, …

```powershell
.\scripts\rotate-subscription.ps1 -FromSub 2 -ToSub 3
```

Create `subscriptions/sub3.tfvars.example` → `sub3.tfvars` or let the script create it.

## Important notes

- **Always run backup before destroy** — `rotate-subscription.ps1` does this automatically.
- **Destroy the old subscription** when done, or PostgreSQL/Container Apps keep charging.
- Keep `backups/subN/` safe until the new subscription is verified.
- For a **custom domain** (same API URL every month), add it in Azure Container Apps — optional advanced setup.
