#!/bin/sh
set -e

echo "Waiting for database..."
python - <<'PY'
import asyncio
import os
import sys
import time

url = os.environ.get("DATABASE_URL", "")
if not url:
    print("DATABASE_URL is not set", file=sys.stderr)
    sys.exit(1)

async def wait_for_db(timeout_s: int = 60) -> None:
    from sqlalchemy.ext.asyncio import create_async_engine
    from sqlalchemy import text

    engine = create_async_engine(url, pool_pre_ping=True)
    deadline = time.time() + timeout_s
    last_err = None
    while time.time() < deadline:
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            await engine.dispose()
            print("Database is ready.")
            return
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(2)
    await engine.dispose()
    print(f"Database not ready: {last_err}", file=sys.stderr)
    sys.exit(1)

asyncio.run(wait_for_db())
PY

echo "Running database migrations..."
alembic upgrade head

echo "Starting MarGem API..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
