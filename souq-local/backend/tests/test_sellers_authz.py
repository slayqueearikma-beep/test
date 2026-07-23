import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

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
    return response.json()


@pytest.mark.asyncio
async def test_seller_cannot_self_review():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-self@example.com", "seller")
        headers = {"Authorization": f"Bearer {seller['access_token']}"}
        created = await client.post(
            "/sellers",
            headers=headers,
            json={
                "business_name": "Self Shop",
                "description": "",
                "address": "1 Main Street",
                "city": "Casablanca",
                "latitude": 33.5,
                "longitude": -7.6,
                "phone": "",
                "cover_image_url": "",
                "category_ids": [],
            },
        )
        assert created.status_code == 201, created.text
        seller_id = created.json()["id"]
        review = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers=headers,
            json={"rating": 5, "comment": "Great"},
        )
        assert review.status_code == 403


@pytest.mark.asyncio
async def test_buyer_can_review_active_seller():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-ok@example.com", "seller")
        buyer = await _register(client, "buyer-ok@example.com", "buyer")
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        created = await client.post(
            "/sellers",
            headers=seller_headers,
            json={
                "business_name": "Public Shop",
                "description": "Nice",
                "address": "2 Main Street",
                "city": "Casablanca",
                "latitude": 34.0,
                "longitude": -6.8,
                "phone": "",
                "cover_image_url": "",
                "category_ids": [],
            },
        )
        assert created.status_code == 201
        seller_id = created.json()["id"]
        review = await client.post(
            f"/sellers/{seller_id}/reviews",
            headers={"Authorization": f"Bearer {buyer['access_token']}"},
            json={"rating": 4, "comment": "Good"},
        )
        assert review.status_code == 201, review.text
        assert review.json()["rating"] == 4
