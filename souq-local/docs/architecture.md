# Souq Local — Architecture

## System overview

```mermaid
flowchart TB
    subgraph clients [Mobile Clients]
        Flutter[Flutter App iOS/Android]
    end

    subgraph auth [Authentication]
        Firebase[Firebase Authentication]
    end

    subgraph backend [Backend Azure]
        API[FastAPI]
        PG[(PostgreSQL)]
        Blob[Azure Blob Storage]
    end

    subgraph external [External Services]
        GMaps[Google Maps API]
        FCM[Firebase Cloud Messaging]
    end

    Flutter --> Firebase
    Flutter -->|Bearer JWT| API
    Flutter --> GMaps
    API --> PG
    API --> Blob
    API --> FCM
```

## Data model (MVP)

```mermaid
erDiagram
    User ||--o| SellerProfile : owns
    SellerProfile ||--o{ Product : lists
    SellerProfile ||--o{ Service : offers
    SellerProfile ||--o{ Review : receives
    User ||--o{ Review : writes
    SellerProfile }o--o{ Category : tagged
    WarningZone ||--|| City : located_in

    User {
        uuid id PK
        string firebase_uid UK
        string email
        enum account_type
        string display_name
    }

    SellerProfile {
        uuid id PK
        uuid user_id FK
        string business_name
        text description
        string address
        string city
        float latitude
        float longitude
        string phone
        int achievement_stars
        bool is_active
    }

    Review {
        uuid id PK
        uuid seller_id FK
        uuid buyer_id FK
        int rating
        text comment
        datetime created_at
    }

    WarningZone {
        uuid id PK
        string name
        text description
        float latitude
        float longitude
        float radius_meters
        string city
    }
```

## Achievement star logic

Achievement stars are derived from **five-star reviews only**:

```python
achievement_stars = five_star_review_count // 100
```

Recomputed on each new review and stored on `SellerProfile.achievement_stars` for fast map/profile display.

## API surface (MVP)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| POST | `/auth/register` | Register user metadata after Firebase signup |
| GET | `/auth/me` | Current user profile |
| GET | `/categories` | List business categories |
| GET | `/sellers` | List/search sellers (city, category, q) |
| POST | `/sellers` | Create seller profile (seller accounts) |
| GET | `/sellers/{id}` | Seller detail + products + services |
| PATCH | `/sellers/{id}` | Update seller profile |
| GET | `/sellers/map` | GeoJSON-style pins for map view |
| POST | `/sellers/{id}/reviews` | Submit review (buyers) |
| GET | `/sellers/{id}/reviews` | List reviews |
| GET | `/warning-zones` | Scam-prone area markers by city |
| POST | `/uploads/presign` | Presigned URL for Azure Blob upload |

## Security

- Firebase ID tokens verified on protected routes
- Sellers can only mutate their own profile
- Buyers can only submit one review per seller (update allowed)
- Rate limiting and input validation on public endpoints (production)

## Deployment (Azure)

1. **Azure Database for PostgreSQL** — primary datastore
2. **Azure Container Apps** — FastAPI container
3. **Azure Blob Storage** — product/service images
4. **Azure Key Vault** — secrets (DB, Firebase, Maps keys)
5. **Firebase** — auth + push (mobile SDK)

## Future phases

- In-app messaging, favorites, reservations, click & collect
- Premium seller tiers (featured listings, analytics)
- Admin dashboard, business verification, multi-language (AR/FR/EN)
- AI-powered search
