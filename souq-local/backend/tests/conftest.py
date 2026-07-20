import os

import pytest_asyncio
from sqlalchemy import text

os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local",
)
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("JWT_SECRET_KEY", "test-jwt-secret-key-minimum-32-characters-long")


@pytest_asyncio.fixture(scope="session")
async def prepare_database():
    from app.database import engine
    from app.models import Base

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        for table in (
            "refresh_tokens",
            "reviews",
            "products",
            "services",
            "seller_categories",
            "seller_profiles",
            "warning_zones",
            "users",
            "categories",
        ):
            await conn.execute(text(f"DELETE FROM {table}"))
    await engine.dispose()
