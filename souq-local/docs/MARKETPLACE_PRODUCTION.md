# MarGem Marketplace — Production Architecture

MarGem is a Morocco-focused local marketplace connecting buyers with nearby sellers.

## Current production capabilities

### Identity & security
- Buyer / seller accounts with bcrypt passwords and JWT access tokens
- Refresh token rotation, reuse detection, logout-all, device sessions
- Email verification + password reset (SMTP when configured; secure log fallback in development)
- Account status (`active` / `suspended` / `deleted`), roles (`buyer` / `seller` / `admin` / `support`)
- MFA-ready `mfa_factors` table
- Rate limiting, security headers, request size limits, structured audit logs

### Guest experience
- Browse without an account
- Local guest cart persisted on device
- Seamless cart migration to the authenticated account on register/login

### Commerce
- Cart, wishlist, addresses
- Checkout with cash-on-delivery (`cod`) and card-later architecture hook
- Orders with stock reservation and buyer cancel (pending/accepted)
- Seller order workflow: accept → ready → complete / reject
- Inventory (`stock_quantity`, SKU)

### Seller operations
- Dashboard analytics (revenue, orders, views, ratings)
- Coupons
- Business verification request queue
- Messaging with buyers
- Notifications
- Premium / Seller Pro subscription plans

### Buyer operations
- Orders history + detail
- Wishlist
- In-app messaging to sellers
- Premium (MarGem Plus)

### Admin APIs
- List users, suspend accounts
- Seller verification approve/reject
- Audit log records

## Key API groups

| Area | Prefix / paths |
|---|---|
| Auth | `/auth/*` |
| Catalog / sellers | `/sellers/*`, `/categories` |
| Commerce | `/cart/*`, `/wishlist/*`, `/checkout`, `/orders/*`, `/buyer/addresses` |
| Seller ops | `/seller/orders`, `/seller/analytics`, `/seller/coupons`, `/seller/verification/request` |
| Messaging | `/messages/*` |
| Notifications | `/notifications/*` |
| Subscriptions | `/subscriptions/*` |
| Admin | `/admin/*` |

## Migrations

```bash
alembic upgrade head
# includes 005 seller fields + 006 marketplace production foundation
```

## Email

Set in environment for production delivery:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_FROM=MarGem <noreply@margem.ma>
PUBLIC_APP_URL=https://margem.ma
```

Without SMTP, verification/reset tokens are logged server-side (never in production responses).

## Billing note

`POST /subscriptions/subscribe/{plan_code}` activates premium with `provider=manual` until CMI/Stripe webhook billing is connected. Schema already stores `provider` + `provider_reference` for that integration.
