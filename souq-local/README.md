# MarGem — Morocco local discovery platform

Discover Morocco's hidden gems. Buyers find shops, services, and local sellers; sellers get a professional storefront and connect directly with customers.

MarGem is a **discovery and connection** platform — not a traditional e-commerce checkout app. Transactions happen outside the platform. Full product capabilities are documented in [docs/MARKETPLACE_PRODUCTION.md](docs/MARKETPLACE_PRODUCTION.md).

## Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter, Riverpod, go_router |
| API | FastAPI, SQLAlchemy, PostgreSQL |
| Auth | JWT (email/password) + optional Firebase |
| Cloud | Azure Container Apps, PostgreSQL, Blob Storage, Key Vault |
| Maps | Google Maps Platform |

## Quick start (local)

```bash
cd souq-local
docker compose up
```

In another terminal:

```bash
cd mobile
flutter pub get
flutter run
```

**No demo accounts are seeded.** Register buyer and seller accounts through the app.

API docs: http://localhost:8000/docs

## Production deployment

See [.azure/deployment-plan.md](.azure/deployment-plan.md) for Azure (PostgreSQL, Key Vault, Container Apps).

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

## Security features

- bcrypt password hashing
- JWT access tokens (7-day expiry, configurable)
- Rate limiting (120 req/min default)
- Security headers (HSTS, X-Frame-Options, nosniff)
- CORS restricted via environment
- `AUTH_DEV_BYPASS=false` in production
- Azure Key Vault for secrets
- PostgreSQL SSL in Azure

## Project structure

```
souq-local/
├── backend/          # FastAPI API + Alembic migrations
├── mobile/           # Flutter app (MarGem)
├── infra/
│   ├── terraform/    # Terraform (recommended)
│   └── main.bicep    # Bicep alternative
├── .azure/           # Deployment guide
└── docker-compose.yml
```
