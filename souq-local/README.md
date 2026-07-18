# MarGem — Morocco local business marketplace

Discover Morocco's hidden gems. Buyers find shops and services; sellers get an online presence.

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

**Demo API accounts** (after seed):
- `buyer@demo.local` / `demo1234`
- `seller@demo.local` / `demo1234`

API docs: http://localhost:8000/docs

## Production deployment

See [.azure/deployment-plan.md](.azure/deployment-plan.md) for Azure setup (~$50–90/month).

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
