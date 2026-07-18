# MarGem — Azure deployment plan (Terraform)

## Architecture

| Component | Azure service | Purpose |
|-----------|---------------|---------|
| API | Container Apps | FastAPI backend |
| Database | PostgreSQL Flexible Server | Users, sellers, reviews |
| Images | Blob Storage | Product/seller photos |
| Secrets | Key Vault | JWT, DB password, storage keys |
| Registry | Container Registry | API Docker images |

Estimated cost: **~$50–90 USD/month** at launch.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Docker (to build API image)

## 1. Login to Azure

```bash
az login
```

## 2. Deploy with Terraform

```bash
cd souq-local/infra/terraform

cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `postgres_admin_password` — strong password
- `jwt_secret_key` — at least 32 random characters

```bash
terraform init
terraform plan
terraform apply
```

Save the outputs:
```bash
terraform output api_url
terraform output postgres_host
```

## 3. Build and push API container

```bash
ACR=$(terraform output -raw container_registry_login_server)
RG=$(terraform output -raw resource_group_name)

az acr login --name margemregistry
cd ../../backend
az acr build --registry margemregistry --image margem-api:1.0.0 .

az containerapp update \
  --name margem-prod-api \
  --resource-group "$RG" \
  --image "${ACR}/margem-api:1.0.0"
```

## 4. Run database migrations

```bash
export DATABASE_URL="postgresql+asyncpg://margemadmin:YOUR_PASSWORD@$(terraform output -raw postgres_host):5432/margem?ssl=require"

cd ../../backend
pip install -r requirements.txt
alembic upgrade head
python scripts/seed.py
```

## 5. Configure mobile app

```bash
flutter run \
  --dart-define=API_BASE_URL=$(terraform output -raw api_url) \
  --dart-define=DEMO_FALLBACK=false
```

## 6. Security checklist (production)

- [ ] `AUTH_DEV_BYPASS=false` (set by Terraform)
- [ ] Strong `jwt_secret_key` in `terraform.tfvars`
- [ ] PostgreSQL firewall: restrict beyond Azure services if needed
- [ ] CORS: set exact app origins in `terraform.tfvars`
- [ ] Google Maps API key restricted by package name
- [ ] Enable Application Insights (optional add-on)
- [ ] Store `terraform.tfvars` securely — never commit it

## Local development (full stack)

```bash
cd souq-local
docker compose up
```

API: http://localhost:8000  
Demo accounts after seed:
- buyer@demo.local / demo1234
- seller@demo.local / demo1234

## Alternative: Bicep

Bicep templates remain in `infra/main.bicep` if you prefer ARM over Terraform.
