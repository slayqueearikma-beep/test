import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str, account_type: str = "buyer") -> dict:
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


async def _create_seller_with_product(client: AsyncClient) -> tuple[dict, str, str]:
    seller = await _register(client, "merchant@example.com", "seller")
    headers = {"Authorization": f"Bearer {seller['access_token']}"}
    created = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": "Spice House",
            "description": "Local spices",
            "address": "12 Medina Street",
            "city": "Marrakech",
            "latitude": 31.6,
            "longitude": -8.0,
            "phone": "+212600000001",
            "cover_image_url": "",
            "logo_image_url": "",
            "category_ids": [],
        },
    )
    assert created.status_code == 201, created.text
    seller_id = created.json()["id"]
    product = await client.post(
        f"/sellers/{seller_id}/products",
        headers=headers,
        json={
            "name": "Saffron",
            "description": "Grade A",
            "price_mad": 120,
            "image_url": "",
            "stock_quantity": 10,
        },
    )
    assert product.status_code == 201, product.text
    return seller, seller_id, product.json()["id"]


@pytest.mark.asyncio
async def test_cart_checkout_and_seller_order_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller_auth, seller_id, product_id = await _create_seller_with_product(client)
        buyer = await _register(client, "shopper@example.com", "buyer")
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        seller_headers = {"Authorization": f"Bearer {seller_auth['access_token']}"}

        added = await client.post(
            "/cart/items",
            headers=buyer_headers,
            json={"product_id": product_id, "quantity": 2},
        )
        assert added.status_code == 201, added.text

        wish = await client.post(f"/wishlist/products/{product_id}", headers=buyer_headers)
        assert wish.status_code == 201

        address = await client.post(
            "/buyer/addresses",
            headers=buyer_headers,
            json={
                "label": "Home",
                "recipient_name": "Fatima",
                "phone": "+212611111111",
                "address_line1": "1 Avenue Hassan II",
                "city": "Marrakech",
                "is_default": True,
            },
        )
        assert address.status_code == 201, address.text

        checkout = await client.post(
            "/checkout",
            headers=buyer_headers,
            json={"address_id": address.json()["id"], "payment_method": "cod"},
        )
        assert checkout.status_code == 201, checkout.text
        orders = checkout.json()
        assert len(orders) == 1
        order_id = orders[0]["id"]
        assert orders[0]["total_mad"] == 240

        seller_orders = await client.get("/seller/orders", headers=seller_headers)
        assert seller_orders.status_code == 200
        assert any(o["id"] == order_id for o in seller_orders.json())

        accepted = await client.post(f"/seller/orders/{order_id}/accept", headers=seller_headers, json={})
        assert accepted.status_code == 200
        assert accepted.json()["status"] == "accepted"

        completed = await client.post(f"/seller/orders/{order_id}/complete", headers=seller_headers)
        assert completed.status_code == 200
        assert completed.json()["status"] == "completed"

        analytics = await client.get("/seller/analytics", headers=seller_headers)
        assert analytics.status_code == 200
        assert analytics.json()["completed_orders"] == 1
        assert analytics.json()["revenue_mad"] == 240


@pytest.mark.asyncio
async def test_password_reset_and_email_verify():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client, "resetme@example.com", "buyer")
        headers = {"Authorization": f"Bearer {user['access_token']}"}

        req = await client.post("/auth/verify-email/request", headers=headers)
        assert req.status_code == 204

        # Create reset token via request endpoint
        reset_req = await client.post("/auth/password-reset/request", json={"email": "resetme@example.com"})
        assert reset_req.status_code == 204

        # Pull token from DB for test confirmation
        from app.database import SessionLocal
        from app.models import AuthToken
        from sqlalchemy import select

        async with SessionLocal() as session:
            result = await session.execute(
                select(AuthToken).where(AuthToken.purpose == "password_reset").order_by(AuthToken.created_at.desc())
            )
            # We only have hash — use a known token path instead by issuing via service
        # Re-issue known token through internal helper by hitting register path is hard;
        # use SQL to insert a known token hash.
        import hashlib
        from datetime import UTC, datetime, timedelta
        from uuid import uuid4

        plain = "test-reset-token-value-1234567890"
        async with SessionLocal() as session:
            from app.models import User

            user_row = (await session.execute(select(User).where(User.email == "resetme@example.com"))).scalar_one()
            session.add(
                AuthToken(
                    id=uuid4(),
                    user_id=user_row.id,
                    purpose="password_reset",
                    token_hash=hashlib.sha256(plain.encode()).hexdigest(),
                    expires_at=datetime.now(UTC) + timedelta(hours=1),
                )
            )
            await session.commit()

        confirm = await client.post(
            "/auth/password-reset/confirm",
            json={"token": plain, "new_password": "NewerPass1"},
        )
        assert confirm.status_code == 204, confirm.text

        login = await client.post(
            "/auth/login",
            json={"email": "resetme@example.com", "password": "NewerPass1"},
        )
        assert login.status_code == 200, login.text


@pytest.mark.asyncio
async def test_subscribe_premium():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        buyer = await _register(client, "plus@example.com", "buyer")
        headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        plans = await client.get("/subscriptions/plans")
        assert plans.status_code == 200
        assert len(plans.json()) >= 1
        code = plans.json()[0]["code"]
        sub = await client.post(f"/subscriptions/subscribe/{code}", headers=headers)
        assert sub.status_code == 201, sub.text
        me = await client.get("/auth/me", headers=headers)
        assert me.json()["is_premium"] is True
