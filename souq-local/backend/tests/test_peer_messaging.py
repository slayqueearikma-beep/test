"""Peer messaging: buyer↔seller, seller↔seller, user↔user."""

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


async def _register(client: AsyncClient, account_type: str, name: str) -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": account_type,
            "display_name": name,
        },
    )
    assert res.status_code == 201, res.text
    body = res.json()
    return {
        "email": email,
        "password": password,
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
        "user_id": body["user"]["id"],
    }


async def _create_store(client: AsyncClient, headers: dict, name: str) -> dict:
    res = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": name,
            "description": "Peer messaging test store",
            "address": "12 Rue Example",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.62,
            "phone": "+212600000077",
            "whatsapp_number": "+212600000077",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.asyncio
async def test_seller_to_seller_shares_one_conversation(client: AsyncClient):
    seller_a = await _register(client, "seller", "Seller A")
    seller_b = await _register(client, "seller", "Seller B")
    store_a = await _create_store(client, seller_a["headers"], "Store Alpha")
    store_b = await _create_store(client, seller_b["headers"], "Store Beta")

    first = await client.post(
        f"/messages/sellers/{store_b['id']}",
        headers=seller_a["headers"],
        json={"body": "Hello from Alpha"},
    )
    assert first.status_code == 201, first.text
    conv_id = first.json()["conversation_id"]

    # B replies by messaging A's store — must reuse the same conversation.
    second = await client.post(
        f"/messages/sellers/{store_a['id']}",
        headers=seller_b["headers"],
        json={"body": "Hello back from Beta"},
    )
    assert second.status_code == 201, second.text
    assert second.json()["conversation_id"] == conv_id

    inbox_a = await client.get("/messages/conversations", headers=seller_a["headers"])
    inbox_b = await client.get("/messages/conversations", headers=seller_b["headers"])
    assert inbox_a.status_code == 200
    assert inbox_b.status_code == 200
    assert len(inbox_a.json()) == 1
    assert len(inbox_b.json()) == 1
    assert inbox_a.json()[0]["id"] == conv_id
    assert inbox_b.json()[0]["peer_user_id"] == seller_a["user_id"]

    thread = await client.get(f"/messages/conversations/{conv_id}", headers=seller_a["headers"])
    assert thread.status_code == 200
    bodies = [m["body"] for m in thread.json()]
    assert bodies == ["Hello from Alpha", "Hello back from Beta"]


@pytest.mark.asyncio
async def test_user_to_user_messaging(client: AsyncClient):
    buyer_a = await _register(client, "buyer", "Buyer A")
    buyer_b = await _register(client, "buyer", "Buyer B")

    started = await client.post(
        f"/messages/users/{buyer_b['user_id']}",
        headers=buyer_a["headers"],
        json={"body": "Hi peer"},
    )
    assert started.status_code == 201, started.text
    conv_id = started.json()["conversation_id"]

    reply = await client.post(
        f"/messages/conversations/{conv_id}",
        headers=buyer_b["headers"],
        json={"body": "Hello back"},
    )
    assert reply.status_code == 201, reply.text

    self_msg = await client.post(
        f"/messages/users/{buyer_a['user_id']}",
        headers=buyer_a["headers"],
        json={"body": "noop"},
    )
    assert self_msg.status_code == 400
