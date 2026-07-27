import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str) -> dict:
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "seller",
            "display_name": "Uploader",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_local_presign_and_put_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "storage_backend", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://testserver")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        user = await _register(client, "uploader@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}

        presign = await client.post(
            "/uploads/presign",
            headers=headers,
            json={"filename": "vase.jpg", "content_type": "image/jpeg"},
        )
        assert presign.status_code == 200, presign.text
        body = presign.json()
        assert body["upload_url"].startswith("http://testserver/uploads/local/")
        assert "/media/" in body["public_url"]

        jpeg = b"\xff\xd8\xff" + b"fake-jpeg-bytes" + b"\xff\xd9"
        put = await client.put(
            body["upload_url"],
                headers={
                    "Content-Type": "image/jpeg",
                    "x-ms-blob-type": "BlockBlob",
                    "Authorization": f"Bearer {user['access_token']}",
                },
            content=jpeg,
        )
        assert put.status_code == 201, put.text

        relative = body["public_url"].split("/media/", 1)[1]
        saved = tmp_path / relative
        assert saved.is_file()
        assert saved.read_bytes() == jpeg


@pytest.mark.asyncio
async def test_local_upload_token_cannot_be_used_by_another_account(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "storage_backend", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://testserver")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        owner = await _register(client, "owner@example.com")
        attacker = await _register(client, "attacker@example.com")
        presign = await client.post(
            "/uploads/presign",
            headers={"Authorization": f"Bearer {owner['access_token']}"},
            json={"filename": "private.jpg", "content_type": "image/jpeg"},
        )
        assert presign.status_code == 200, presign.text

        put = await client.put(
            presign.json()["upload_url"],
            headers={
                "Content-Type": "image/jpeg",
                "Authorization": f"Bearer {attacker['access_token']}",
            },
            content=b"\xff\xd8\xff\xd9",
        )
        assert put.status_code == 403
