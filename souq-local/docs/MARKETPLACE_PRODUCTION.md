# MarGem — Local Discovery Platform

MarGem is a Morocco-focused **third-party local marketplace and discovery platform**.

It connects buyers with businesses, service providers, freelancers, stores, restaurants, professionals, and local sellers.

## What MarGem is

- Discover businesses, products, and services near you
- Compare listings and seller profiles
- Contact sellers directly (in-app message, call, WhatsApp, email)
- Complete transactions **outside** the platform using payment methods both parties agree on

## What MarGem is NOT

MarGem does **not**:

- Process payments between buyers and sellers
- Store credit/debit cards or banking credentials for marketplace transactions
- Act as a payment intermediary
- Implement shopping cart or checkout
- Manage shipping, warehousing, or order fulfillment
- Handle in-app refunds or payment disputes for goods/services

Sellers may list accepted payment methods (cash, bank transfer, mobile payment, etc.) for **display only**.

## Current production capabilities

### Identity & security
- Buyer / seller accounts with bcrypt passwords and JWT access tokens
- Refresh token rotation, reuse detection, logout-all, device sessions
- Email verification + password reset
- Account status and roles (`buyer` / `seller` / `admin` / `support`)
- MFA-ready `mfa_factors` table
- Rate limiting, security headers, request size limits, audit logs

### Guest experience
- Browse, search, filter, and view maps without an account
- Local temporary favorites and preferences on device
- Migrate guest favorites into the account on register/login

### Discovery
- Seller storefronts with cover, logo, hours, GPS, website, social links
- Declared payment methods and delivery options (informational)
- Categories, search, map pins, premium-first ranking
- Featured listings, verification badges, premium badges
- Favorites, follow sellers, saved searches, recently viewed
- Report listings/sellers

### Communication (first-class)
- Secure in-app messaging / inquiries
- Contact events for call, WhatsApp, email, SMS, website
- Seller inquiry inbox via conversations

### Seller professional dashboard
- Public storefront + business profile management
- Publish / edit / pause / duplicate / delete listings
- Product & service media, negotiable pricing, coverage areas
- Analytics: profile views, inquiries, favorites, contact clicks, response time
- Verification request queue
- Notifications
- Premium / Seller Pro visibility plans (membership for placement — not buyer↔seller payments)

### Buyer
- Browse & search listings and businesses
- Favorites, follows, reviews
- Contact sellers
- Premium (MarGem Plus) for discovery perks

### Admin APIs
- List users, suspend accounts
- Seller verification approve/reject
- Audit log records

## Key API groups

| Area | Prefix / paths |
|---|---|
| Auth | `/auth/*` |
| Catalog / sellers | `/sellers/*`, `/categories` |
| Discovery | `/favorites/*`, `/follows/*`, `/saved-searches`, `/recently-viewed`, `/reports`, `/contact-events` |
| Seller ops | `/seller/analytics`, `/seller/verification/request` |
| Messaging | `/messages/*` |
| Notifications | `/notifications/*` |
| Subscriptions | `/subscriptions/*` (platform membership / visibility) |
| Admin | `/admin/*` |

## Migrations

```bash
alembic upgrade head
# 005 seller fields → 006 marketplace foundation → 007 discovery platform pivot
# 007 drops cart/orders/addresses/coupons and adds favorites, follows, reports, contact events
```

## Email

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_FROM=MarGem <noreply@margem.ma>
PUBLIC_APP_URL=https://margem.ma
```

Without SMTP, verification/reset tokens are logged server-side (never in production responses).

## Home-server model

API + Postgres run on the seller’s laptop via Docker; media can live on Azure Blob. See root README for `docker-compose.home.yml` and Flutter `--dart-define=API_BASE_URL=...`.
