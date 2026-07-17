# MarGem — Discover Morocco's Hidden Gems

A mobile marketplace that centralizes local businesses with physical stores across Morocco. Buyers discover nearby shops, products, and services; sellers get an online presence without building their own website.

## Architecture

```text
Flutter (iOS + Android)
  -> Firebase Auth (JWT)
  -> FastAPI Backend
  -> PostgreSQL
  -> Azure Blob Storage (images)
  -> Google Maps API (map + directions)
  -> Firebase Cloud Messaging (notifications)
  -> Azure Container Apps (hosting)
```

## Repository structure

```text
souq-local/
├── backend/          # FastAPI API
├── mobile/           # Flutter app
├── docs/             # Architecture and API notes
└── docker-compose.yml
```

## MVP features

| Area | Features |
|------|----------|
| Auth | Register, login, buyer vs seller account type |
| Sellers | Profile, address, map location, photos, categories |
| Buyers | Browse by city, search, filter, reviews, directions |
| Map | Seller pins, category filter, warning zones |
| Reputation | 1–5 stars; 1 achievement star per 100 five-star reviews |

## Local development

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Start PostgreSQL (see docker-compose at repo root)
uvicorn app.main:app --reload --port 8000
```

API docs: http://localhost:8000/docs

### Database

```bash
docker compose up -d postgres
cd backend && alembic upgrade head
```

### Mobile

Requires [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.16+.

```bash
cd mobile
flutter pub get
flutter run
```

Set API base URL in `mobile/lib/core/config/app_config.dart`.

## Environment variables

See `backend/.env.example` for backend configuration. Mobile uses Firebase config files (not committed) and Google Maps API keys per platform.

## Design

Modern, minimal UI inspired by card-based discovery apps:

- Light and dark themes (purple accent in dark mode, orange CTAs)
- Rounded cards, generous spacing, clear typography hierarchy
- Screens: Home, Search, Map, Seller profile, Product detail, Reviews, Auth

## License

Private — all rights reserved.
