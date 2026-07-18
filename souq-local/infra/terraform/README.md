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

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Azure subscription

## Quick deploy

```bash
az login
cd souq-local/infra/terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set postgres_admin_password and jwt_secret_key

terraform init
terraform plan
terraform apply
```

Note the `api_url` output after apply.

## Build and deploy API image

```bash
# If ACR was created (default)
ACR=$(terraform output -raw container_registry_login_server)
RG=$(terraform output -raw resource_group_name)

az acr login --name margemregistry
cd ../../backend
az acr build --registry margemregistry --image margem-api:1.0.0 .

# Update Container App to use ACR image
az containerapp update \
  --name margem-prod-api \
  --resource-group "$RG" \
  --image "${ACR}/margem-api:1.0.0"
```

Or set `api_image` in `terraform.tfvars` before `terraform apply`.

## Database migrations

```bash
export DATABASE_URL="postgresql+asyncpg://margemadmin:YOUR_PASSWORD@$(terraform output -raw postgres_host):5432/margem?ssl=require"

cd ../../backend
pip install -r requirements.txt
alembic upgrade head
python scripts/seed.py
```

## Mobile app

```bash
flutter run \
  --dart-define=API_BASE_URL=$(cd infra/terraform && terraform output -raw api_url) \
  --dart-define=DEMO_FALLBACK=false
```

## Destroy (careful)

```bash
terraform destroy
```

## Bicep alternative

Bicep templates are still available in `infra/main.bicep` if you prefer ARM/Bicep over Terraform.
