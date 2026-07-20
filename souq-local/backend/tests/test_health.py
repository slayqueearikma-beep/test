import pytest
from starlette.requests import Request

from app.main import health


@pytest.mark.asyncio
async def test_health():
    scope = {"type": "http", "method": "GET", "path": "/health", "headers": [], "client": ("testclient", 50000)}
    request = Request(scope)
    result = await health(request)
    assert result["status"] in {"ok", "degraded"}
    assert result["service"] == "MarGem API"
