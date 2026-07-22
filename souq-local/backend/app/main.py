from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import select, text
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import settings
import app.database as database
from app.limiter import limiter
from app.logging_config import configure_logging
from app.middleware.request_context import RequestContextMiddleware
from app.middleware.request_limits import RequestSizeLimitMiddleware
from app.middleware.security import SecurityHeadersMiddleware
from app.models import SubscriptionPlan
from app.routers import auth, catalog, discovery, seller_ops, sellers, uploads

configure_logging(json_logs=settings.app_env in {"production", "prod"})


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure premium plans exist after migrations / fresh create_all environments.
    async with database.SessionLocal() as session:
        existing = await session.execute(select(SubscriptionPlan).limit(1))
        if existing.scalar_one_or_none() is None:
            session.add_all(
                [
                    SubscriptionPlan(
                        id=uuid4(),
                        code="buyer_premium",
                        name="MarGem Plus",
                        description="Saved searches, personalized recommendations, priority support",
                        price_mad=49,
                        billing_period_days=30,
                        features=[
                            "Saved searches sync",
                            "Personalized recommendations",
                            "Priority support",
                            "Early access to featured listings",
                        ],
                    ),
                    SubscriptionPlan(
                        id=uuid4(),
                        code="seller_pro",
                        name="Seller Pro",
                        description="Featured placement, premium storefront, advanced discovery analytics",
                        price_mad=199,
                        billing_period_days=30,
                        features=[
                            "Featured placement",
                            "Premium badge",
                            "Advanced analytics",
                            "Extra media uploads",
                            "Verification priority",
                        ],
                    ),
                ]
            )
            await session.commit()
    yield
    await database.engine.dispose()


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

# Only trust forwarded headers from known reverse-proxy hosts (or loopback in dev).
_proxy_trusted = (
    settings.allowed_hosts
    if settings.allowed_hosts != ["*"]
    else ["127.0.0.1", "localhost"]
)
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=_proxy_trusted)

app.include_router(auth.router)
app.include_router(catalog.router)
app.include_router(sellers.router)
app.include_router(uploads.router)
app.include_router(discovery.router)
app.include_router(seller_ops.router)


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", None) or request.headers.get("x-request-id") or str(uuid4())


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    from fastapi.encoders import jsonable_encoder

    return JSONResponse(
        status_code=422,
        content={
            "detail": jsonable_encoder(exc.errors()),
            "request_id": _request_id(request),
        },
        headers={"X-Request-ID": _request_id(request)},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    import logging

    request_id = _request_id(request)
    logging.getLogger("margem.errors").exception(
        "unhandled_error request_id=%s path=%s", request_id, request.url.path
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


@app.get("/live")
@limiter.exempt
async def live(request: Request):
    """Process liveness — does not check dependencies."""
    return {"status": "ok"}


@app.get("/ready")
@limiter.exempt
async def ready(request: Request):
    """Readiness — fails when the database is unreachable."""
    try:
        async with database.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable", "database": "error"},
        )
    return {"status": "ok", "database": "ok"}


@app.get("/health")
@limiter.exempt
async def health(request: Request):
    db_status = "ok"
    try:
        async with database.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "error"

    if db_status != "ok":
        body: dict[str, str] = {"status": "unavailable", "database": db_status}
        if settings.app_env in {"development", "dev"} or settings.debug:
            body["service"] = settings.app_name
            body["environment"] = settings.app_env
        return JSONResponse(status_code=503, content=body)

    body = {"status": "ok", "database": db_status}
    if settings.app_env in {"development", "dev"} or settings.debug:
        body["service"] = settings.app_name
        body["environment"] = settings.app_env
    return body
