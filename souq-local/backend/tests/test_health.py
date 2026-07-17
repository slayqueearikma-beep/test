import pytest

from app.main import health


@pytest.mark.asyncio
async def test_health():
    result = await health()
    assert result["status"] == "ok"
    assert result["service"] == "MarGem API"
