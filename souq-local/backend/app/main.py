from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import text
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import settings
from app.database import engine
from app.limiter import limiter
from app.logging_config import configure_logging
from app.middleware.request_context import RequestContextMiddleware
from app.middleware.request_limits import RequestSizeLimitMiddleware
from app.middleware.security import SecurityHeadersMiddleware
from app.routers import auth, catalog, commerce, seller_ops, sellers, uploads

configure_logging(json_logs=settings.app_env in {"production", "prod"})


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure premium plans exist after migrations / fresh create_all environments.
    from sqlalchemy import select

    from app.database import SessionLocal
    from app.models import SubscriptionPlan
    from uuid import uuid4

    async with SessionLocal() as session:
        existing = await session.execute(select(SubscriptionPlan).limit(1))
        if existing.scalar_one_or_none() is None:
            session.add_all(
                [
                    SubscriptionPlan(
                        id=uuid4(),
                        code="buyer_premium",
                        name="MarGem Plus",
                        description="Exclusive deals, priority support, unlimited wishlist",
                        price_mad=49,
                        billing_period_days=30,
                        features=["Exclusive deals", "Priority support", "Unlimited wishlist", "Early access"],
                    ),
                    SubscriptionPlan(
                        id=uuid4(),
                        code="seller_pro",
                        name="Seller Pro",
                        description="Boosted visibility, analytics, coupons, featured placement",
                        price_mad=199,
                        billing_period_days=30,
                        features=["Featured placement", "Advanced analytics", "Unlimited coupons", "Priority verification"],
                    ),
                ]
            )
            await session.commit()
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug or settings.app_env == "development" else None,
    redoc_url=None,
    openapi_url="/openapi.json" if settings.debug or settings.app_env == "development" else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
# Outermost first for ProxyHeaders so TrustedHost/HSTS see the real scheme.
app.add_middleware(SlowAPIMiddleware)
app.add_middleware(RequestContextMiddleware)
app.add_middleware(RequestSizeLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)

if settings.allowed_hosts != ["*"]:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    max_age=600,
)
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")

app.include_router(auth.router)
app.include_router(catalog.router)
app.include_router(sellers.router)
app.include_router(uploads.router)
app.include_router(commerce.router)
app.include_router(seller_ops.router)


@app.get("/health")
@limiter.exempt
async def health(request: Request):
    db_status = "ok"
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "error"

    status = "ok" if db_status == "ok" else "degraded"
    body: dict[str, str] = {"status": status, "database": db_status}
    if settings.app_env in {"development", "dev"} or settings.debug:
        body["service"] = settings.app_name
        body["environment"] = settings.app_env
    return body
