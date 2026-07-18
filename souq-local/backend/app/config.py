from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MarGem API"
    app_env: str = "development"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    # Auth — set AUTH_DEV_BYPASS=false in production
    auth_dev_bypass: bool = False
    firebase_credentials_path: str = ""
    jwt_secret_key: str = "change-this-secret-in-production-use-key-vault"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7

    azure_storage_connection_string: str = ""
    azure_storage_container: str = "margem-media"

    cors_origins: list[str] = ["http://localhost:3000"]
    allowed_hosts: list[str] = ["*"]

    rate_limit: str = "120/minute"

    default_cities: list[str] = [
        "Casablanca",
        "Rabat",
        "Marrakech",
        "Fes",
        "Tangier",
        "Agadir",
        "Meknes",
        "Oujda",
    ]


settings = Settings()
