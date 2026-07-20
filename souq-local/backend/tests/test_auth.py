import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.password_policy import validate_password_strength


def test_password_policy_requires_complexity():
    with pytest.raises(ValueError):
        validate_password_strength("password")
    validate_password_strength("SecurePass1")


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_requires_strong_password():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/auth/register",
            json={
                "email": "user@example.com",
                "password": "short",
                "account_type": "buyer",
                "display_name": "Test",
            },
        )
    assert response.status_code == 422


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_and_login_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = "prod-test@example.com"
        password = "SecurePass1"

        register = await client.post(
            "/auth/register",
            json={
                "email": email,
                "password": password,
                "account_type": "buyer",
                "display_name": "Prod Test",
            },
        )
        assert register.status_code == 201
        body = register.json()
        assert body["access_token"]
        assert body["refresh_token"]
        token = body["access_token"]

        login = await client.post(
            "/auth/login",
            json={"email": email, "password": password},
        )
        assert login.status_code == 200
        assert login.json()["refresh_token"]

        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email
        assert "firebase_uid" not in me.json()

        refresh = await client.post(
            "/auth/refresh",
            json={"refresh_token": body["refresh_token"]},
        )
        assert refresh.status_code == 200
        assert refresh.json()["access_token"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_email_case_insensitive():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        first = await client.post(
            "/auth/register",
            json={
                "email": "Case@Example.com",
                "password": "SecurePass1",
                "account_type": "buyer",
                "display_name": "Case User",
            },
        )
        assert first.status_code == 201

        second = await client.post(
            "/auth/register",
            json={
                "email": "case@example.com",
                "password": "SecurePass1",
                "account_type": "buyer",
                "display_name": "Dup",
            },
        )
        assert second.status_code == 409
