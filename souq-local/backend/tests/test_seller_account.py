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


async def _create_seller(client: AsyncClient, token: str, name: str = "My Shop") -> dict:
    response = await client.post(
        "/sellers",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "business_name": name,
            "description": "Desc",
            "address": "1 Main Street",
            "city": "Casablanca",
            "latitude": 33.5,
            "longitude": -7.6,
            "phone": "+212600000000",
            "cover_image_url": "",
            "logo_image_url": "",
            "opening_hours": {
                "days": {"Mon": True, "Tue": True, "Wed": True, "Thu": True, "Fri": True, "Sat": True, "Sun": False},
                "open": "09:00",
                "close": "21:00",
            },
            "category_ids": [],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_get_my_seller_and_dashboard():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-me@example.com", "seller")
        token = seller["access_token"]
        created = await _create_seller(client, token)

        me = await client.get("/sellers/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200, me.text
        body = me.json()
        assert body["id"] == created["id"]
        assert body["business_name"] == "My Shop"
        assert body["opening_hours"]["open"] == "09:00"

        dash = await client.get("/sellers/me/dashboard", headers={"Authorization": f"Bearer {token}"})
        assert dash.status_code == 200, dash.text
        stats = dash.json()
        assert stats["seller_id"] == created["id"]
        assert stats["product_count"] == 0
        assert stats["profile_view_count"] == 0


@pytest.mark.asyncio
async def test_product_crud_and_profile_views():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-crud@example.com", "seller")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token, name="CRUD Shop")
        seller_id = created["id"]

        product = await client.post(
            f"/sellers/{seller_id}/products",
            headers=headers,
            json={"name": "Tagine", "description": "Clay", "price_mad": 120, "image_url": ""},
        )
        assert product.status_code == 201, product.text
        product_id = product.json()["id"]

        updated = await client.patch(
            f"/sellers/{seller_id}/products/{product_id}",
            headers=headers,
            json={"price_mad": 150, "is_available": False},
        )
        assert updated.status_code == 200, updated.text
        assert updated.json()["price_mad"] == 150
        assert updated.json()["is_available"] is False

        dash = await client.get("/sellers/me/dashboard", headers=headers)
        assert dash.json()["product_count"] == 1
        assert dash.json()["available_product_count"] == 0

        # Public view increments counter
        public = await client.get(f"/sellers/{seller_id}")
        assert public.status_code == 200
        assert public.json()["profile_view_count"] >= 1

        # Owner view does not increment further when authenticated as owner
        before = public.json()["profile_view_count"]
        owner_view = await client.get(f"/sellers/{seller_id}", headers=headers)
        assert owner_view.status_code == 200
        assert owner_view.json()["profile_view_count"] == before

        deleted = await client.delete(f"/sellers/{seller_id}/products/{product_id}", headers=headers)
        assert deleted.status_code == 204

        dash2 = await client.get("/sellers/me/dashboard", headers=headers)
        assert dash2.json()["product_count"] == 0


@pytest.mark.asyncio
async def test_seller_cannot_access_other_seller_products():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        a = await _register(client, "seller-a@example.com", "seller")
        b = await _register(client, "seller-b@example.com", "seller")
        a_shop = await _create_seller(client, a["access_token"], name="A Shop")
        await _create_seller(client, b["access_token"], name="B Shop")

        product = await client.post(
            f"/sellers/{a_shop['id']}/products",
            headers={"Authorization": f"Bearer {a['access_token']}"},
            json={"name": "Item", "description": "", "image_url": ""},
        )
        assert product.status_code == 201
        product_id = product.json()["id"]

        hijack = await client.patch(
            f"/sellers/{a_shop['id']}/products/{product_id}",
            headers={"Authorization": f"Bearer {b['access_token']}"},
            json={"name": "Stolen"},
        )
        assert hijack.status_code == 404


@pytest.mark.asyncio
async def test_update_seller_profile_hours():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-hours@example.com", "seller")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token)

        patched = await client.patch(
            f"/sellers/{created['id']}",
            headers=headers,
            json={
                "business_name": "Updated Shop",
                "opening_hours": {
                    "days": {"Mon": False, "Tue": True},
                    "open": "10:30",
                    "close": "18:00",
                },
            },
        )
        assert patched.status_code == 200, patched.text
        assert patched.json()["business_name"] == "Updated Shop"
        assert patched.json()["opening_hours"]["open"] == "10:30"


@pytest.mark.asyncio
async def test_change_password():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "seller-pw@example.com", "seller")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        bad = await client.post(
            "/auth/me/password",
            headers=headers,
            json={"current_password": "WrongPass1", "new_password": "NewerPass1"},
        )
        assert bad.status_code == 401

        ok = await client.post(
            "/auth/me/password",
            headers=headers,
            json={"current_password": "SecurePass1", "new_password": "NewerPass1"},
        )
        assert ok.status_code == 204

        login = await client.post(
            "/auth/login",
            json={"email": "seller-pw@example.com", "password": "NewerPass1"},
        )
        assert login.status_code == 200, login.text
