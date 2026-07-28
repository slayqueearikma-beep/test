# MarGem — Morocco local discovery platform

Discover Morocco's hidden gems. Buyers find shops, services, and local sellers; sellers get a professional storefront and connect directly with customers.

MarGem is a **discovery and connection** platform — not a traditional e-commerce checkout app. Transactions happen outside the platform. Full product capabilities are documented in [docs/MARKETPLACE_PRODUCTION.md](docs/MARKETPLACE_PRODUCTION.md).

Production readiness (score, blockers, checklist): [docs/PRODUCTION_READINESS_AUDIT.md](docs/PRODUCTION_READINESS_AUDIT.md).

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

### Realistic demo marketplace data

For development and UI review only, seed an idempotent Casablanca marketplace:

```bash
cd backend
PYTHONPATH=. python scripts/seed_marketplace_demo.py
```

It creates 80 storefronts, 240 listings, reviews, conversations/messages,
notifications, favorites, recently viewed items, and saved searches. Do not
run it against a production customer database.

## Production deployment

See [.azure/deployment-plan.md](.azure/deployment-plan.md) for Azure (PostgreSQL, Key Vault, Container Apps).

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

## Security features

- bcrypt password hashing
- JWT access tokens (default 60 minutes) + refresh tokens (default 7 days)
- Rate limiting (default 300/minute global, 30/minute auth)
- Security headers (HSTS, X-Frame-Options, nosniff)
- CORS / ALLOWED_HOSTS restricted in production (no wildcards)
- `AUTH_DEV_BYPASS=false` and non-default JWT required in production
- Azure Key Vault for secrets (Terraform path)
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
