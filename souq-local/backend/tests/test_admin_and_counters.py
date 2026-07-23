"""Admin/staff authorization and atomic seller counters."""

from uuid import UUID, uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from starlette.responses import JSONResponse

import app.database as database
from app.main import app
from app.middleware.request_limits import RequestSizeLimitMiddleware
from app.models import SellerProfile, User, UserRole, VerificationStatus

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str = "buyer") -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": account_type,
            "display_name": account_type.title(),
        },
    )
    assert res.status_code == 201, res.text
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {res.json()['access_token']}"},
    }


async def _set_role(email: str, role: UserRole) -> None:
    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = role
        await session.commit()


async def _create_pending_seller(client: AsyncClient) -> UUID:
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json={
            "business_name": "Pending Shop",
            "description": "Awaiting verification",
            "address": "1 Test St",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.59,
            "phone": "+212600000099",
            "whatsapp_number": "+212600000099",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert profile.status_code == 201, profile.text
    seller_id = UUID(profile.json()["id"])
    async with database.SessionLocal() as session:
        row = await session.get(SellerProfile, seller_id)
        assert row is not None
        row.verification_status = VerificationStatus.PENDING
        await session.commit()
    return seller_id


@pytest.mark.asyncio
async def test_support_can_list_pending_but_cannot_verify(client: AsyncClient):
    seller_id = await _create_pending_seller(client)
    support = await _register(client, "buyer")
    await _set_role(support["email"], UserRole.SUPPORT)

    pending = await client.get("/admin/sellers/pending", headers=support["headers"])
    assert pending.status_code == 200, pending.text
    assert any(item["id"] == str(seller_id) for item in pending.json())

    verify = await client.post(
        f"/admin/sellers/{seller_id}/verify",
        headers=support["headers"],
        params={"approve": "true"},
    )
    assert verify.status_code == 403


@pytest.mark.asyncio
async def test_admin_can_verify_seller(client: AsyncClient):
    seller_id = await _create_pending_seller(client)
    admin = await _register(client, "buyer")
    await _set_role(admin["email"], UserRole.ADMIN)

    verify = await client.post(
        f"/admin/sellers/{seller_id}/verify",
        headers=admin["headers"],
        params={"approve": "true"},
    )
    assert verify.status_code == 204, verify.text

    pending = await client.get("/admin/sellers/pending", headers=admin["headers"])
    assert pending.status_code == 200
    assert all(item["id"] != str(seller_id) for item in pending.json())


@pytest.mark.asyncio
async def test_favorite_count_increments_atomically(client: AsyncClient):
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json={
            "business_name": "Counter Shop",
            "description": "Counters",
            "address": "2 Test St",
            "city": "Casablanca",
            "latitude": 34.02,
            "longitude": -6.83,
            "phone": "+212600000088",
            "whatsapp_number": "+212600000088",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert profile.status_code == 201, profile.text
    seller_id = profile.json()["id"]

    buyer_a = await _register(client, "buyer")
    buyer_b = await _register(client, "buyer")
    for buyer in (buyer_a, buyer_b):
        res = await client.post(f"/favorites/sellers/{seller_id}", headers=buyer["headers"])
        assert res.status_code == 201, res.text

    detail = await client.get(f"/sellers/{seller_id}")
    assert detail.status_code == 200
    assert int(detail.json().get("favorite_count", 0)) == 2

    remove = await client.delete(f"/favorites/sellers/{seller_id}", headers=buyer_a["headers"])
    assert remove.status_code == 204
    detail = await client.get(f"/sellers/{seller_id}")
    assert detail.status_code == 200
    assert int(detail.json().get("favorite_count", 0)) == 1


@pytest.mark.asyncio
async def test_request_body_too_large_returns_413(client: AsyncClient, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "max_request_body_bytes", 64)
    huge = "x" * 200
    res = await client.post(
        "/auth/register",
        json={
            "email": f"big-{uuid4().hex[:6]}@example.com",
            "password": "SecurePass1",
            "account_type": "buyer",
            "display_name": huge,
        },
    )
    assert res.status_code == 413
    assert res.json()["detail"] == "Request body too large"


@pytest.mark.asyncio
async def test_admin_can_grant_premium(client: AsyncClient):
    target = await _register(client, "buyer")
    admin = await _register(client, "buyer")
    await _set_role(admin["email"], UserRole.ADMIN)

    me = await client.get("/auth/me", headers=target["headers"])
    assert me.status_code == 200
    user_id = me.json()["id"]

    grant = await client.post(
        f"/admin/users/{user_id}/premium",
        headers=admin["headers"],
        json={"plan_code": "buyer_premium", "days": 14},
    )
    assert grant.status_code == 201, grant.text
    assert grant.json()["provider"] == "admin_grant"

    me2 = await client.get("/auth/me", headers=target["headers"])
    assert me2.status_code == 200
    assert me2.json()["is_premium"] is True


@pytest.mark.asyncio
async def test_suspended_user_cannot_refresh(client: AsyncClient):
    user = await _register(client, "buyer")
    login = await client.post(
        "/auth/login",
        json={"email": user["email"], "password": "SecurePass1"},
    )
    assert login.status_code == 200, login.text
    refresh = login.json()["refresh_token"]

    admin = await _register(client, "buyer")
    await _set_role(admin["email"], UserRole.ADMIN)
    me = await client.get("/auth/me", headers=user["headers"])
    user_id = me.json()["id"]

    suspend = await client.patch(
        f"/admin/users/{user_id}/status",
        headers=admin["headers"],
        params={"status": "suspended"},
    )
    assert suspend.status_code == 204, suspend.text

    refreshed = await client.post("/auth/refresh", json={"refresh_token": refresh})
    assert refreshed.status_code in {401, 403}


@pytest.mark.asyncio
async def test_whitespace_message_rejected(client: AsyncClient):
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json={
            "business_name": "Msg Shop",
            "description": "Msgs",
            "address": "3 Test St",
            "city": "Casablanca",
            "latitude": 34.03,
            "longitude": -5.0,
            "phone": "+212600000077",
            "whatsapp_number": "+212600000077",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert profile.status_code == 201, profile.text
    buyer = await _register(client, "buyer")
    res = await client.post(
        f"/messages/sellers/{profile.json()['id']}",
        headers=buyer["headers"],
        json={"body": "   "},
    )
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_chunked_body_over_limit_returns_413():
    """Chunked uploads without a trustworthy Content-Length still hit the hard cap."""
    reached_app = False

    async def dummy_app(scope, receive, send):
        nonlocal reached_app
        reached_app = True
        response = JSONResponse({"ok": True})
        await response(scope, receive, send)

    mw = RequestSizeLimitMiddleware(dummy_app, max_bytes=64)
    messages: list[dict] = []
    chunks = [b"a" * 40, b"b" * 40]

    async def receive():
        if chunks:
            return {"type": "http.request", "body": chunks.pop(0), "more_body": bool(chunks)}
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "path": "/",
        "raw_path": b"/",
        "query_string": b"",
        "headers": [(b"content-type", b"application/json")],
        "client": ("127.0.0.1", 123),
        "server": ("test", 80),
        "scheme": "http",
    }
    await mw(scope, receive, send)
    assert any(m.get("status") == 413 for m in messages if m["type"] == "http.response.start")
    assert not reached_app
