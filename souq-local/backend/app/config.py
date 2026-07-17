from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MarGem API"
    app_env: str = "development"
    debug: bool = True

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    firebase_credentials_path: str = ""
    auth_dev_bypass: bool = True

    azure_storage_connection_string: str = ""
    azure_storage_container: str = "souq-media"

    cors_origins: list[str] = ["*"]

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
