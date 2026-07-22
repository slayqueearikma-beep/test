"""Production settings and auth hardening tests."""

import pytest
from pydantic import ValidationError

from app.config import Settings


def test_production_rejects_default_jwt_secret():
    with pytest.raises(ValidationError, match="JWT_SECRET_KEY"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            auth_dev_bypass=False,
            jwt_secret_key="change-this-secret-in-production-use-key-vault",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            azure_storage_connection_string="DefaultEndpointsProtocol=https;AccountName=x;AccountKey=y;EndpointSuffix=core.windows.net",
        )


def test_production_rejects_debug_true():
    with pytest.raises(ValidationError, match="DEBUG"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=True,
            auth_dev_bypass=False,
            jwt_secret_key="a-real-production-secret-key-32chars-min",
            cors_origins=["https://margem.ma"],
            allowed_hosts=["api.margem.ma"],
            azure_storage_connection_string="DefaultEndpointsProtocol=https;AccountName=x;AccountKey=y;EndpointSuffix=core.windows.net",
        )


def test_production_accepts_rotated_secret():
    settings = Settings(
        _env_file=None,
        app_env="production",
        debug=False,
        auth_dev_bypass=False,
        jwt_secret_key="a-real-production-secret-key-32chars-min",
        cors_origins=["https://margem.ma"],
        allowed_hosts=["api.margem.ma"],
        azure_storage_connection_string="DefaultEndpointsProtocol=https;AccountName=x;AccountKey=y;EndpointSuffix=core.windows.net",
        smtp_host="smtp.example.com",
    )
    assert settings.app_env == "production"


@pytest.mark.asyncio
async def test_invalid_token_returns_401_without_firebase(prepare_database):
    from httpx import ASGITransport, AsyncClient

    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/auth/me", headers={"Authorization": "Bearer not-a-valid-jwt"})
        assert res.status_code == 401
        assert res.json()["detail"] == "Invalid token"
