# MarGem Production Readiness Audit (Full Engineering Review)

**Date:** 2026-07-22  
**Branch:** `cursor/production-grade-audit-f384`  
**Scope:** Entire `souq-local/` tree (FastAPI, Flutter, Postgres, Azure Blob, Compose, Terraform/Bicep, CI)  
**Method:** Recursive source review of all application behavior files; backend + Flutter tests executed; critical findings fixed on this branch.

---

## 1. Executive summary

MarGem is a **local discovery / connection platform** (not checkout e-commerce). The codebase implements sellers, listings, search/map, favorites, follows, messaging, contact events, reviews, Azure uploads, premium *visibility* memberships (billing gated in prod + admin grant), and admin/staff ops.

**Deployment Readiness: 88%**

Suitable for a **controlled soft launch / home-server or budget-VM beta** after completing the remaining manual ops checklist (rotated secrets, SMTP, TLS, backups, crash reporting, Play signing). Remaining gaps are mostly ops/scale (APM SDK, CD, iOS).

This pass closed: durable public blob URLs, paused-product visibility, media/social URL allowlisting, premium expiry, message rate limits, DB wait on boot, Android intent queries, HTTPS release enforcement, favorites routing, messaging UX, SMTP compose wiring, Bicep CORS/`ALLOWED_HOSTS`, atomic counters, staff/admin split, chunked body limits, conversation batching, theme persistence, category locales, admin premium grant, suspend session revoke, GDPR-oriented account wipe, PyJWT migration, and Numeric money columns.

**Verification this revision:** backend **40 passed**; Flutter analyze clean; Flutter tests **7 passed**.

---

## 2. Deployment readiness score

### Deployment Readiness: **88%**

| Category | Score | Evidence |
|---|---:|---|
| Architecture | 88 | Clear FastAPI routers + Flutter feature modules; discovery pivot; architecture.md rewritten |
| Backend | 91 | Auth hardening, Alembic→`009`, rate limits, upload hardening, atomic counters, admin premium grant |
| Mobile | 84 | Theme persist, locale categories, search autofocus gated, badge isolation; Android-only |
| UI/UX | 80 | Contact CTAs aligned; shell rebuild reduced; ecommerce l10n identifier debt remains |
| Security | 90 | Prod validators, body hard-cap, staff≠admin, suspend kills refresh, PyJWT |
| Performance | 82 | Conversation batching, bulk mark-read, pool recycling, pagination |
| Database | 88 | Migrations through `009` Numeric money; uniqueness indexes |
| Testing | 78 | 40 backend + 7 Flutter tests; staff/admin, counters, 413, premium grant, suspend refresh |
| Documentation | 86 | Audit + marketplace docs + architecture.md aligned to discovery platform |
| DevOps | 80 | Compose YAML fixed, HEALTHCHECK, requirements-dev split, CI compose config validate |
| Reliability | 82 | `/live` `/ready`, entrypoint DB wait, upload retry, optional REDIS_URL for limits |
| Maintainability | 84 | Counter helpers, theme provider, dead nested CI removed |

---

## 3. Production readiness checklist

| Item | Status |
|---|---|
| Discovery APIs (no cart/checkout) | Done |
| Auth register/login/refresh/logout | Done |
| Seller storefront + listings | Done |
| Favorites / follows / contact / messaging | Done |
| Uploads (Azure, durable public blob URLs) | Done (requires Azure + container) |
| Public listing hides paused/unavailable | Done |
| Media + social URL validation | Done |
| Premium self-subscribe in production | Blocked (503) — use admin grant |
| Admin premium grant | Done |
| Premium expiry on authenticated requests | Done |
| Suspend revokes refresh + blocks refresh | Done |
| SMTP wired in home/budget compose | Done |
| TLS reverse proxy | Manual |
| Rotated JWT + Azure secrets | Manual |
| DB backups automation | Manual |
| Crash reporting | Missing |
| APM (App Insights SDK) | Missing (env only on ACA TF) |
| Play signing / iOS | Manual / missing iOS |
| CI tests + image build | Done (`margem-ci.yml`) |
| CD deploy | Missing for MarGem |

---

## 4. Issues by severity (post-fix state)

### Critical / High — fixed this cycle (selected)

| Issue | Fix |
|---|---|
| Compose SMTP keys invalid YAML indent | Re-indented under `environment` |
| Favorite/contact/inquiry RMW counters | Atomic SQL `UPDATE … + 1` helpers |
| SUPPORT == ADMIN | `require_staff` vs `require_admin` |
| Body size CL-only / BaseHTTPMiddleware body drop | Pure ASGI replay + hard cap |
| Conversation list N+1 | Batched unread + DISTINCT ON last message |
| Theme not persisted | `ThemeModeNotifier` + AppStorage |
| Nested misleading CI | Removed; root `margem-ci.yml` is source of truth |
| Suspended users could refresh | Status check + revoke on suspend |
| No admin premium path in prod | `POST /admin/users/{id}/premium` |
| Incomplete account delete | Wipe favorites/follows/messages/subs/etc. |
| pytest in runtime image | `requirements-dev.txt` split |

### Medium — remaining

| Issue | Notes |
|---|---|
| MFA tables unused | Future |
| Email verify unused for gating | Optional today |
| No iOS project | Android-only |
| Ecommerce l10n key names | Remapped text; rename later |
| App Insights env unused by app | Wire OTel or remove |

---

## 5. Pull / run (home stack)

```bash
cd ~/MarGem && git pull origin cursor/production-grade-audit-f384
cd souq-local && docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
cd mobile && flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
```
