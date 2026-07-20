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
from app.routers import auth, catalog, sellers, uploads

configure_logging(json_logs=settings.app_env in {"production", "prod"})


@asynccontextmanager
async def lifespan(app: FastAPI):
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


@app.get("/health")
@limiter.limit("60/minute")
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
