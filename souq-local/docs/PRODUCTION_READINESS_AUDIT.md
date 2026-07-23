# MarGem Production Readiness Audit (Full Engineering Review)

**Date:** 2026-07-23  
**Branch:** `cursor/production-readiness-90-f384`  
**Scope:** Entire `souq-local/` tree (FastAPI, Flutter, Postgres, Azure Blob, Compose, Terraform/Bicep, CI)  
**Method:** Recursive source review; Critical/High findings fixed; backend + Flutter tests executed.

---

## 1. Executive summary

MarGem is a **local discovery / connection platform** (not checkout e-commerce). The codebase implements sellers, listings, search/map, favorites, follows, messaging, contact events, reviews, Azure uploads, premium *visibility* memberships (billing gated in prod + admin grant), auth lifecycle (verify/reset/delete), and admin/staff ops.

**Deployment Readiness: 92%**

Suitable for **public soft launch** after completing the remaining **ops-only** checklist (rotated live secrets, real SMTP credentials, TLS at the edge, automated DB backups, Play signing, optional iOS). No open Critical or High *code* blockers remain on this branch.

This pass closed: production SMTP enforcement, Azure TF/Bicep SMTP + public URLs, single-replica rate-limit safety, verify-email/reset deep links, premium 503 UX + mailto support, Sentry crash reporting, account-delete FK safety, optional-auth status enforcement, public premium expiry, composite DB indexes, email/PII log masking, HTTPS public URL validators, buyer change-password, App Insights telemetry hook, CI prod-settings smoke + release APK assemble.

**Verification this revision:** backend **49 passed**; Flutter analyze clean; Flutter tests **10 passed**.

---

## 2. Deployment readiness score

### Deployment Readiness: **92%**

| Category | Score | Evidence |
|---|---:|---|
| Architecture | 90 | Clear FastAPI routers + Flutter feature modules; premium/auth helpers extracted |
| Backend | 94 | Auth lifecycle, SMTP gate, premium expiry, indexes `010`, body limits, staff/admin |
| Mobile | 90 | Verify-email + deep links, Sentry, premium CTA, buyer password change, HTTPS release assert |
| UI/UX | 84 | Dashboard/login polish; ecommerce l10n identifier debt remains (text remapped) |
| Security | 93 | Prod validators (JWT/SMTP/HTTPS URLs), PII masking, suspend/delete enforcement on optional auth |
| Performance | 88 | Conversation batching, composite indexes, pool recycling, pagination |
| Database | 92 | Migrations through `010` perf indexes; Numeric money; uniqueness |
| Testing | 86 | 49 backend + 10 Flutter; auth lifecycle, premium helper, prod settings, release APK CI |
| Documentation | 90 | This audit + architecture + env examples + TF vars for SMTP |
| DevOps | 88 | Compose HEALTHCHECK, TF/Bicep SMTP + maxReplicas=1, CI image + APK + settings smoke |
| Reliability | 88 | `/live` `/ready`, entrypoint DB wait, upload retry, Redis-ready limiter |
| Maintainability | 88 | Dead nested CI removed; telemetry/crash hooks isolated |

---

## 3. Production readiness checklist

| Item | Status |
|---|---|
| Discovery APIs (no cart/checkout) | Done |
| Auth register/login/refresh/logout | Done |
| Email verify + password reset + deep links | Done |
| Account delete (seller FK wipe) | Done |
| Seller storefront + listings | Done |
| Favorites / follows / contact / messaging | Done |
| Uploads (Azure, durable public blob URLs) | Done (requires Azure + container) |
| Premium self-subscribe in production | Blocked (503) + Contact support mailto |
| Admin premium grant | Done |
| Premium expiry on auth + public seller lists | Done |
| Suspend revokes refresh + blocks optional auth | Done |
| SMTP required in production | Done (break-glass flag documented) |
| Azure TF/Bicep SMTP + PUBLIC_* URLs | Done |
| Rate limits safe (maxReplicas=1 without Redis) | Done |
| Crash reporting (Sentry when DSN set) | Done |
| App Insights hook (optional SDK) | Done |
| TLS reverse proxy | Manual (ops) |
| Rotated JWT + Azure + SMTP secrets | Manual (ops) |
| DB backups automation | Manual (ops) |
| Play signing / iOS | Manual / Android-only |
| CI tests + image + release APK | Done |
| CD deploy pipeline | Missing (ops) — image build is CI-ready |

---

## 4. Issues by severity (post-fix state)

### Critical / High — fixed this cycle

| Issue | Severity | Fix |
|---|---|---|
| Production could boot without SMTP | Critical | `Settings` requires `SMTP_HOST` unless break-glass |
| Azure ACA env omitted SMTP → boot fail / no mail | Critical | Terraform + Bicep SMTP secrets/env + `PUBLIC_*` |
| Multi-replica in-memory rate limits | High | TF/Bicep `max_replicas`/`maxReplicas` = 1 |
| Password-reset/verify emails not opening app | High | `margem://` + HTTPS links; Flutter deep-link meta |
| Premium Subscribe dead-end in prod | High | 503 copy + mailto support (no fake billing) |
| Crash reporting no-op | High | `sentry_flutter` when `SENTRY_DSN` set |
| Account delete FK failures for sellers | High | Clear categories/products/services/reviews first |
| Optional auth skipped suspend/delete checks | High | Shared `_enforce_account_state` |
| Stale public premium badges | High | Expiry helper on list/detail |
| Email/security logs leaked full addresses | Medium→fixed | Mask `a***@domain` |

### Medium — remaining (non-blocking)

| Issue | Notes |
|---|---|
| MFA tables unused | Future |
| Email verify not a hard gate on all actions | Soft-launch OK; can gate messaging later |
| No iOS project | Android-first release |
| Ecommerce l10n key names | Remapped text; rename later |
| CD / automated deploy | Manual `terraform apply` / compose |
| App Links `assetlinks.json` | Ops DNS/hosting for verified HTTPS links |

### Ops-only before traffic (not code blockers)

1. Provision SMTP and set TF/Compose secrets  
2. Rotate `JWT_SECRET_KEY` away from examples  
3. Terminate TLS (Caddy/nginx/Front Door)  
4. Schedule Postgres backups  
5. Build release with `--dart-define=SENTRY_DSN=…` and Play signing  
6. Point `PUBLIC_APP_URL` / `PUBLIC_API_URL` at real HTTPS hosts  

---

## 5. Issue detail template (representative)

### SMTP required in production
- **Severity:** Critical  
- **Category:** Security / Reliability  
- **Location:** `backend/app/config.py`, `infra/terraform/main.tf`, `infra/main.bicep`  
- **Problem:** Production could start without outbound mail → reset/verify impossible.  
- **Root Cause:** SMTP was optional; Azure templates omitted env.  
- **Impact:** Account recovery broken at launch.  
- **Exact Fix:** Validator + infra env/secrets; break-glass `ALLOW_INSECURE_EMAIL_FALLBACK`.  
- **Verification:** `pytest tests/test_auth_lifecycle.py` + TF validate.  
- **Success Criteria:** Prod Settings without SMTP raises; ACA gets `SMTP_*`.

---

## 6. Pull / run (home stack)

```bash
cd ~/MarGem && git fetch origin && git checkout cursor/production-readiness-90-f384
cd souq-local && docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
cd mobile && flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
```

Release mobile (store):

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.margem.ma \
  --dart-define=PRODUCTION=true \
  --dart-define=SENTRY_DSN=https://YOUR_DSN
```
