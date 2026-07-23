import json
import logging
from typing import Any

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger("margem.config")


def _normalize_host(host: str) -> str:
    """Starlette TrustedHost compares hostname without port."""
    value = host.strip().strip('"').strip("'")
    if "://" in value:
        value = value.split("://", 1)[1]
    return value.split("/")[0].split(":")[0]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MarGem API"
    app_env: str = "development"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    auth_dev_bypass: bool = False
    firebase_credentials_path: str = ""
    jwt_secret_key: str = "change-this-secret-in-production-use-key-vault"
    jwt_algorithm: str = "HS256"
    jwt_access_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 7
    bcrypt_rounds: int = 12

    azure_storage_connection_string: str = ""
    azure_storage_container: str = "margem-media"
    # azure = Blob SAS uploads; local = laptop disk under LOCAL_MEDIA_ROOT (home server).
    storage_backend: str = "azure"
    local_media_root: str = "./data/media"
    max_upload_bytes: int = 8_388_608

    cors_origins: list[str] = ["http://localhost:3000"]
    allowed_hosts: list[str] = ["*"]

    rate_limit: str = "300/minute"
    auth_rate_limit: str = "30/minute"
    max_request_body_bytes: int = 1_048_576
    redis_url: str = ""
    allow_insecure_email_fallback: bool = False

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = "MarGem <noreply@margem.ma>"
    smtp_use_tls: bool = True
    public_app_url: str = "https://margem.ma"
    public_api_url: str = "http://localhost:8000"

    default_cities: list[str] = [
        "Casablanca",
    ]

    @field_validator("storage_backend", mode="before")
    @classmethod
    def normalize_storage_backend(cls, value: Any) -> str:
        if value is None or value == "":
            return "azure"
        cleaned = str(value).strip().lower()
        if cleaned not in {"azure", "local"}:
            raise ValueError("STORAGE_BACKEND must be 'azure' or 'local'")
        return cleaned

    @field_validator("azure_storage_connection_string", "azure_storage_container", "local_media_root", mode="before")
    @classmethod
    def strip_secrets(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip().strip('"').strip("'")
        return value

    @field_validator("cors_origins", "allowed_hosts", mode="before")
    @classmethod
    def parse_string_list(cls, value: Any) -> list[str]:
        if isinstance(value, str):
            stripped = value.strip().strip("'").strip('"')
            if stripped.startswith("["):
                try:
                    return json.loads(stripped)
                except json.JSONDecodeError:
                    # Docker/.env often mangles JSON quotes — fall back to loose parse.
                    inner = stripped.strip("[]")
                    return [item.strip().strip('"').strip("'") for item in inner.split(",") if item.strip()]
            return [item.strip().strip('"').strip("'") for item in stripped.split(",") if item.strip()]
        return value

    @field_validator("allowed_hosts", mode="after")
    @classmethod
    def normalize_allowed_hosts(cls, value: list[str]) -> list[str]:
        if value == ["*"] or "*" in value:
            return ["*"]
        normalized: list[str] = []
        for host in value:
            clean = _normalize_host(host)
            if clean and clean not in normalized:
                normalized.append(clean)
        for loopback in ("localhost", "127.0.0.1"):
            if loopback not in normalized:
                normalized.append(loopback)
        return normalized

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.app_env in {"production", "prod"}:
            if self.debug:
                raise ValueError("DEBUG must be false in production")
            if self.auth_dev_bypass:
                raise ValueError("AUTH_DEV_BYPASS must be false in production")
            if len(self.jwt_secret_key) < 32:
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production")
            # Reject the documented default even when it already meets length checks.
            if self.jwt_secret_key.startswith("change-this-secret"):
                raise ValueError("JWT_SECRET_KEY must be rotated away from the default value in production")
            if "*" in self.cors_origins:
                raise ValueError("CORS_ORIGINS must not include '*' in production")
            if "*" in self.allowed_hosts:
                raise ValueError("ALLOWED_HOSTS must not include '*' in production")
            if self.storage_backend == "azure" and not self.azure_storage_connection_string:
                raise ValueError("AZURE_STORAGE_CONNECTION_STRING is required in production when STORAGE_BACKEND=azure")
            if self.storage_backend == "local" and not self.public_api_url:
                raise ValueError("PUBLIC_API_URL is required in production when STORAGE_BACKEND=local")
            if not self.smtp_host and not self.allow_insecure_email_fallback:
                raise ValueError(
                    "SMTP_HOST is required in production (set ALLOW_INSECURE_EMAIL_FALLBACK=true "
                    "only for emergency break-glass when outbound mail is unavailable)"
                )
            if not self.smtp_host and self.allow_insecure_email_fallback:
                logger.warning(
                    "ALLOW_INSECURE_EMAIL_FALLBACK enabled — password reset and verification "
                    "emails will only be logged, not delivered"
                )
            if self.public_api_url.startswith("http://") and "localhost" not in self.public_api_url:
                raise ValueError("PUBLIC_API_URL must use HTTPS in production (non-localhost)")
            if self.public_app_url.startswith("http://") and "localhost" not in self.public_app_url:
                raise ValueError("PUBLIC_APP_URL must use HTTPS in production (non-localhost)")
        return self


settings = Settings()
logger.info(
    "allowed_hosts=%s cors_origins=%s app_env=%s",
    settings.allowed_hosts,
    settings.cors_origins,
    settings.app_env,
)
