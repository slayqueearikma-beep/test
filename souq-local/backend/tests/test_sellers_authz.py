import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import User

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str, account_type: str) -> dict:
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": account_type,
            "display_name": email.split("@")[0],
        },
    )
    assert response.status_code == 201, response.text
    await _verify_email(email)
    return response.json()


async def _create_store(client: AsyncClient, headers: dict, name: str) -> dict:
    created = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": name,
            "description": "Nice",
            "address": "2 Main Street",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.62,
            "phone": "+212600000010",
            "cover_image_url": "",
            "category_ids": [],
        },
    )
    assert created.status_code == 201, created.text
    return created.json()


async def _verify_email(email: str) -> None:
    """Mark the fixture account verified; verification itself is tested in auth tests."""
    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        from datetime import UTC, datetime

        user.email_verified_at = datetime.now(UTC)
        await session.commit()


@pytest.mark.asyncio
async def test_seller_cannot_self_review():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-self@example.com", "seller")
        headers = {"Authorization": f"Bearer {seller['access_token']}"}
        store = await _create_store(client, headers, "Self Shop")
        seller_id = store["id"]

        eligibility = await client.get(
            f"/sellers/{seller_id}/reviews/eligibility",
            headers=headers,
        )
        assert eligibility.status_code == 200
        assert eligibility.json()["can_review"] is False
        assert eligibility.json()["reason"] == "own_store"

        review = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=headers,
            json={
                "product_quality": 5,
                "customer_service": 5,
                "communication": 5,
                "trustworthiness": 5,
                "comment": "Great",
            },
        )
        assert review.status_code == 403


@pytest.mark.asyncio
async def test_buyer_requires_completed_interaction_before_review():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-gate@example.com", "seller")
        buyer = await _register(client, "buyer-gate@example.com", "buyer")
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        store = await _create_store(client, seller_headers, "Public Shop")
        seller_id = store["id"]

        blocked = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=buyer_headers,
            json={
                "product_quality": 4,
                "customer_service": 4,
                "communication": 4,
                "trustworthiness": 4,
                "comment": "Good",
            },
        )
        assert blocked.status_code == 403

        eligibility = await client.get(
            f"/sellers/{seller_id}/reviews/eligibility",
            headers=buyer_headers,
        )
        assert eligibility.status_code == 200
        assert eligibility.json()["can_review"] is False
        assert eligibility.json()["reason"] == "no_completed_transaction"


@pytest.mark.asyncio
async def test_buyer_can_review_after_verified_storefront_message():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-ok@example.com", "seller")
        buyer = await _register(client, "buyer-ok@example.com", "buyer")
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        store = await _create_store(client, seller_headers, "Public Shop")
        seller_id = store["id"]
        await _verify_email("buyer-ok@example.com")

        # Client-reported contact events are analytics only and cannot unlock a
        # trust signal. A server-side storefront message is required instead.
        contact = await client.post(
            f"/messages/sellers/{seller_id}",
            headers=buyer_headers,
            json={"body": "Hello, I would like to know more about this item."},
        )
        assert contact.status_code == 201, contact.text

        eligibility = await client.get(
            f"/sellers/{seller_id}/reviews/eligibility",
            headers=buyer_headers,
        )
        assert eligibility.status_code == 200
        assert eligibility.json()["can_review"] is True

        review = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=buyer_headers,
            json={
                "product_quality": 5,
                "customer_service": 4,
                "communication": 3,
                "trustworthiness": 4,
                "comment": "Solid experience",
            },
        )
        assert review.status_code == 201, review.text
        body = review.json()
        assert body["product_quality"] == 5
        assert body["customer_service"] == 4
        assert body["communication"] == 3
        assert body["trustworthiness"] == 4
        assert body["overall_rating"] == 4.0
        assert body["rating"] == 4

        listed = await client.get(f"/sellers/{seller_id}/reviews")
        assert listed.status_code == 200
        assert len(listed.json()) == 1
        assert listed.json()[0]["overall_rating"] == 4.0

        detail = await client.get(f"/sellers/{seller_id}")
        assert detail.status_code == 200
        assert detail.json()["average_rating"] == 4.0
        assert detail.json()["review_count"] == 1
        assert detail.json()["avg_product_quality"] == 5.0
        assert detail.json()["avg_customer_service"] == 4.0


@pytest.mark.asyncio
async def test_contact_event_cannot_unlock_review_eligibility():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-contact-only@example.com", "seller")
        buyer = await _register(client, "buyer-contact-only@example.com", "buyer")
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        store = await _create_store(client, seller_headers, "Contact-only Shop")
        await _verify_email("buyer-contact-only@example.com")

        contact = await client.post(
            "/contact-events",
            headers=buyer_headers,
            json={"seller_id": store["id"], "channel": "whatsapp"},
        )
        assert contact.status_code == 201, contact.text
        eligibility = await client.get(
            f"/sellers/{store['id']}/reviews/eligibility",
            headers=buyer_headers,
        )
        assert eligibility.status_code == 200
        assert eligibility.json()["can_review"] is False
        assert eligibility.json()["reason"] == "no_completed_transaction"


@pytest.mark.asyncio
async def test_review_rejects_incomplete_categories():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-val@example.com", "seller")
        buyer = await _register(client, "buyer-val@example.com", "buyer")
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        store = await _create_store(client, seller_headers, "Validated Shop")
        seller_id = store["id"]

        await client.post(
            "/contact-events",
            headers=buyer_headers,
            json={"seller_id": seller_id, "channel": "call"},
        )

        incomplete = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=buyer_headers,
            json={"rating": 5, "comment": "legacy"},
        )
        assert incomplete.status_code == 422

        too_long = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=buyer_headers,
            json={
                "product_quality": 5,
                "customer_service": 5,
                "communication": 5,
                "trustworthiness": 5,
                "comment": "x" * 501,
            },
        )
        assert too_long.status_code == 422
