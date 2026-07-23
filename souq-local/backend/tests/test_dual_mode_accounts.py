"""Dual-mode accounts: one email can browse as buyer and own a storefront."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str = "buyer") -> dict:
    email = f"dual-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": account_type,
            "display_name": "Dual User",
        },
    )
    assert res.status_code == 201, res.text
    body = res.json()
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
        "user": body["user"],
    }


@pytest.mark.asyncio
async def test_buyer_can_open_storefront_on_same_account(client: AsyncClient):
    buyer = await _register(client, "buyer")
    assert buyer["user"]["has_seller_profile"] is False

    created = await client.post(
        "/sellers",
        headers=buyer["headers"],
        json={
            "business_name": "My Dual Store",
            "description": "Opened later",
            "address": "12 Rue Example",
            "city": "Casablanca",
            "latitude": 33.5,
            "longitude": -7.6,
            "phone": "+212600000088",
            "whatsapp_number": "+212600000088",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert created.status_code == 201, created.text

    me = await client.get("/auth/me", headers=buyer["headers"])
    assert me.status_code == 200
    assert me.json()["has_seller_profile"] is True
    assert me.json()["account_type"] == "seller"

    dashboard = await client.get("/sellers/me/dashboard", headers=buyer["headers"])
    assert dashboard.status_code == 200
    assert dashboard.json()["business_name"] == "My Dual Store"


@pytest.mark.asyncio
async def test_seller_can_review_another_business(client: AsyncClient):
    seller_a = await _register(client, "seller")
    seller_b = await _register(client, "seller")

    store_a = await client.post(
        "/sellers",
        headers=seller_a["headers"],
        json={
            "business_name": "Store A",
            "description": "",
            "address": "12 Rue Example",
            "city": "Rabat",
            "latitude": 34.0,
            "longitude": -6.8,
            "phone": "+212600000091",
            "whatsapp_number": "+212600000091",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert store_a.status_code == 201, store_a.text

    store_b = await client.post(
        "/sellers",
        headers=seller_b["headers"],
        json={
            "business_name": "Store B",
            "description": "",
            "address": "14 Rue Example",
            "city": "Rabat",
            "latitude": 34.01,
            "longitude": -6.81,
            "phone": "+212600000092",
            "whatsapp_number": "+212600000092",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert store_b.status_code == 201, store_b.text

    review = await client.post(
        f"/sellers/{store_b.json()['id']}/reviews",
        headers=seller_a["headers"],
        json={"rating": 5, "comment": "Great neighbor shop"},
    )
    assert review.status_code == 201, review.text
