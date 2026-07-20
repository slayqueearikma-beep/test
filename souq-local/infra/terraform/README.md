# MarGem — Terraform (Azure)

Deploys the full MarGem backend stack on Azure:

| Resource | Purpose |
|----------|---------|
| Resource Group | All MarGem resources |
| PostgreSQL Flexible Server | Users, sellers, reviews |
| Blob Storage | Product/seller images |
| Key Vault | Secrets (RBAC-enabled) |
| Container Apps Environment + App | FastAPI API |
| Container Registry (optional) | API Docker images |

Estimated cost: **~$50–90 USD/month** at launch.

## Monthly subscription rotation (most common)

If you have **multiple Azure subscriptions** (e.g. free credits that run out each month), use **one at a time**:

1. **Month 1** — deploy on `sub1`
2. Budget hits **$0** — **migrate all data** to `sub2` with `rotate-subscription.ps1`
3. Repeat with `sub3`, `sub4`, …

You only run **one** stack at a time. Full walkthrough: **[subscriptions/MONTHLY-ROTATION.md](subscriptions/MONTHLY-ROTATION.md)**

**Windows (PowerShell):**

```powershell
cd souq-local\infra\terraform

# Month 1
.\scripts\switch-subscription.ps1 -Sub 1

# When sub1 credits are gone — migrate ALL data to sub2 (not from zero)
.\scripts\rotate-subscription.ps1 -FromSub 1 -ToSub 2
```

Each month gets its own tfvars (`subscriptions/sub1.tfvars`, `sub2.tfvars`, …) and state file (`terraform-sub1.tfstate`, …).

**Data preserved:** database + images are backed up and restored automatically. See [MONTHLY-ROTATION.md](subscriptions/MONTHLY-ROTATION.md).

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- One or more Azure subscriptions (rotated month by month)

## Quick deploy (single subscription, no rotation)

```bash
az login
az account list --output table

cd souq-local/infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit subscription_id, postgres_admin_password, jwt_secret_key

terraform init
terraform apply
```

## Per-subscription config files

```bash
cp subscriptions/sub1.tfvars.example subscriptions/sub1.tfvars
cp subscriptions/sub2.tfvars.example subscriptions/sub2.tfvars
```

| Field | sub1 (month 1) | sub2 (month 2) |
|-------|----------------|----------------|
| `subscription_id` | First subscription GUID | Second subscription GUID |
| `subscription_alias` | `sub1` | `sub2` |

Resource names include the alias (`rg-margem-prod-sub1`, `margemregsub2`, …) so each month’s stack is unique in Azure.

### Separate state per month

```bash
terraform apply -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
terraform apply -state=terraform-sub2.tfstate -var-file=subscriptions/sub2.tfvars
```

Remote state and workspaces are optional — see [MONTHLY-ROTATION.md](subscriptions/MONTHLY-ROTATION.md).

## Build and deploy API image

```bash
ACR=$(terraform output -raw container_registry_login_server)
ACR_NAME=$(terraform output -raw acr_name)
RG=$(terraform output -raw resource_group_name)

az acr login --name "$ACR_NAME"
cd ../../backend
az acr build --registry "$ACR_NAME" --image margem-api:1.0.0 .
```

Set `api_image` in your active month’s tfvars, then `terraform apply` again.

## Mobile app after a rotation

The API URL changes each month. Rebuild with the new URL:

```bash
flutter build apk \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=$(terraform output -state=terraform-sub2.tfstate -raw api_url)
```

## Destroy (when credits run out)

```bash
terraform destroy -state=terraform-sub1.tfstate -var-file=subscriptions/sub1.tfvars
```

Or use `.\scripts\destroy-subscription.ps1 -Sub 1`.

## Bicep alternative

Bicep templates are still available in `infra/main.bicep` if you prefer ARM/Bicep over Terraform.
