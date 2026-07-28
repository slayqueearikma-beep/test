"""Discovery marketplace: favorites, contact, messaging — no cart/checkout/orders."""

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


async def _register(client: AsyncClient, account_type: str, email: str | None = None) -> dict:
    email = email or f"{account_type}-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": account_type,
            "display_name": account_type.title(),
        },
    )
    assert res.status_code == 201, res.text
    tokens = res.json()
    return {"email": email, "password": password, "token": tokens["access_token"], "headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _create_seller_with_product(client: AsyncClient) -> tuple[dict, dict, dict]:
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json={
            "business_name": "Atlas Crafts",
            "description": "Handmade goods",
            "address": "12 Medina Street",
            "city": "Casablanca",
            "latitude": 31.63,
            "longitude": -8.0,
            "phone": "+212600000001",
            "whatsapp_number": "+212600000001",
            "payment_methods": ["cash", "bank_transfer"],
            "delivery_methods": ["in_store", "local_delivery"],
            "website_url": "https://example.com",
        },
    )
    assert profile.status_code == 201, profile.text
    seller_body = profile.json()
    product = await client.post(
        f"/sellers/{seller_body['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Ceramic Bowl",
            "description": "Hand-thrown",
            "price_mad": 120,
            "price_negotiable": True,
            "accepted_payment_methods": ["cash"],
            "delivery_options": ["pickup"],
        },
    )
    assert product.status_code == 201, product.text
    return seller, seller_body, product.json()


@pytest.mark.asyncio
async def test_global_search_returns_paginated_products_and_sellers(client: AsyncClient):
    _, seller, product = await _create_seller_with_product(client)
    response = await client.get("/search", params={"q": "ceramic", "mode": "all", "limit": 10})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["total_products"] == 1
    assert body["products"][0]["id"] == product["id"]
    assert body["products"][0]["seller_id"] == seller["id"]

    seller_response = await client.get("/search", params={"q": "atlas", "mode": "sellers"})
    assert seller_response.status_code == 200, seller_response.text
    assert seller_response.json()["sellers"][0]["id"] == seller["id"]


@pytest.mark.asyncio
async def test_favorites_follow_contact_and_messaging(client: AsyncClient):
    seller, seller_body, product = await _create_seller_with_product(client)
    buyer = await _register(client, "buyer")

    fav = await client.post(
        f"/favorites/products/{product['id']}",
        headers=buyer["headers"],
    )
    assert fav.status_code == 201, fav.text
    assert fav.json()["product_name"] == "Ceramic Bowl"

    favs = await client.get("/favorites", headers=buyer["headers"])
    assert favs.status_code == 200
    assert len(favs.json()) == 1

    follow = await client.post(
        f"/follows/sellers/{seller_body['id']}",
        headers=buyer["headers"],
    )
    assert follow.status_code == 201, follow.text
    assert follow.json()["business_name"] == "Atlas Crafts"

    contact = await client.post(
        "/contact-events",
        headers=buyer["headers"],
        json={"seller_id": seller_body["id"], "channel": "whatsapp"},
    )
    assert contact.status_code == 201, contact.text

    msg = await client.post(
        f"/messages/sellers/{seller_body['id']}",
        headers=buyer["headers"],
        json={"body": "Is this bowl still available?"},
    )
    assert msg.status_code == 201, msg.text

    analytics = await client.get("/seller/analytics", headers=seller["headers"])
    assert analytics.status_code == 200, analytics.text
    body = analytics.json()
    assert body["favorite_count"] >= 1
    assert body["contact_click_count"] >= 1
    assert body["inquiry_count"] >= 1
    assert "revenue_mad" not in body
    assert "order_count" not in body

    storefront = await client.get(f"/sellers/{seller_body['id']}")
    assert storefront.status_code == 200
    detail = storefront.json()
    assert "cash" in detail["payment_methods"]
    assert detail["whatsapp_number"]
    assert detail["website_url"] == "https://example.com"
    assert "created_at" in detail
    assert detail.get("follower_count", 0) >= 1

    opened = await client.post(
        f"/messages/sellers/{seller_body['id']}/open",
        headers=buyer["headers"],
    )
    assert opened.status_code == 200, opened.text
    thread = opened.json()
    assert thread["id"]
    assert thread.get("last_message_preview", "") == ""

    thread_messages = await client.get(
        f"/messages/conversations/{thread['id']}",
        headers=buyer["headers"],
    )
    assert thread_messages.status_code == 200
    # Prior inquiry message may exist; open must not auto-append a canned body.
    bodies = [m["body"] for m in thread_messages.json()]
    assert all("Is it still available?" not in b for b in bodies)


@pytest.mark.asyncio
async def test_guest_favorites_migrate_and_report(client: AsyncClient):
    _, seller_body, product = await _create_seller_with_product(client)
    buyer = await _register(client, "buyer")

    migrated = await client.post(
        "/favorites/migrate-guest",
        headers=buyer["headers"],
        json={"items": [{"product_id": product["id"]}, {"seller_id": seller_body["id"]}]},
    )
    assert migrated.status_code == 200, migrated.text
    assert len(migrated.json()) >= 1

    report = await client.post(
        "/reports",
        json={
            "seller_id": seller_body["id"],
            "reason": "spam",
            "details": "Looks suspicious",
        },
    )
    assert report.status_code == 201, report.text


@pytest.mark.asyncio
async def test_report_rejects_unknown_seller(client: AsyncClient):
    report = await client.post(
        "/reports",
        json={"seller_id": str(uuid4()), "reason": "spam", "details": "x"},
    )
    assert report.status_code == 404


@pytest.mark.asyncio
async def test_product_rejects_invalid_media_url(client: AsyncClient):
    seller, seller_body, _ = await _create_seller_with_product(client)
    bad = await client.post(
        f"/sellers/{seller_body['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Bad Media",
            "media_urls": ["javascript:alert(1)"],
        },
    )
    assert bad.status_code == 422


@pytest.mark.asyncio
async def test_subscribe_premium_visibility(client: AsyncClient):
    seller = await _register(client, "seller")
    plans = await client.get("/subscriptions/plans")
    assert plans.status_code == 200
    assert len(plans.json()) >= 1
    code = plans.json()[-1]["code"]
    sub = await client.post(f"/subscriptions/subscribe/{code}", headers=seller["headers"])
    assert sub.status_code == 201, sub.text
    me = await client.get("/auth/me", headers=seller["headers"])
    assert me.status_code == 200
    assert me.json()["is_premium"] is True


@pytest.mark.asyncio
async def test_ecommerce_endpoints_removed(client: AsyncClient):
    buyer = await _register(client, "buyer")
    for path in ("/cart", "/checkout", "/orders", "/wishlist", "/buyer/addresses"):
        res = await client.get(path, headers=buyer["headers"])
        assert res.status_code == 404, path
