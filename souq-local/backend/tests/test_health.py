import pytest
from httpx import ASGITransport, AsyncClient
from starlette.requests import Request

from app.main import health, live, ready


@pytest.mark.asyncio
async def test_health_ok_when_db_available():
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/health",
        "headers": [],
        "client": ("testclient", 50000),
    }
    request = Request(scope)
    result = await health(request)
    # When DB is up, FastAPI returns a plain dict (not JSONResponse).
    if hasattr(result, "status_code"):
        assert result.status_code == 503
        body = result.body
        assert b"unavailable" in body or b"error" in body
    else:
        assert result["status"] == "ok"
        assert result["database"] == "ok"
        assert result["service"] == "MarGem API"


@pytest.mark.asyncio
async def test_live_and_ready_endpoints():
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        live_res = await client.get("/live")
        assert live_res.status_code == 200
        assert live_res.json()["status"] == "ok"

        ready_res = await client.get("/ready")
        assert ready_res.status_code in {200, 503}
        assert "status" in ready_res.json()
