"""Local disk media storage for home-server deployments."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote

from app.config import settings

logger = logging.getLogger("margem.storage")

_TOKEN_TTL_MINUTES = 15


def _upload_signing_key() -> bytes:
    """Use an independent signing secret outside development."""
    return (settings.upload_token_secret or settings.jwt_secret_key).encode("utf-8")


def media_root() -> Path:
    root = Path(settings.local_media_root).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


def public_media_base_url() -> str:
    return settings.public_api_url.rstrip("/") + "/media"


def public_media_url(blob_name: str) -> str:
    encoded = "/".join(quote(part, safe="") for part in blob_name.split("/"))
    return f"{public_media_base_url()}/{encoded}"


def _b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def sign_upload_token(*, blob_name: str, content_type: str, user_id: str) -> str:
    payload = {
        "blob": blob_name,
        "ct": content_type,
        "uid": user_id,
        "exp": int(
            (datetime.now(timezone.utc) + timedelta(minutes=_TOKEN_TTL_MINUTES)).timestamp()
        ),
    }
    body = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = hmac.new(
        _upload_signing_key(),
        body.encode("ascii"),
        hashlib.sha256,
    ).digest()
    return f"{body}.{_b64url_encode(signature)}"


def verify_upload_token(token: str) -> dict:
    try:
        body, signature = token.split(".", 1)
    except ValueError as exc:
        raise ValueError("Invalid upload token") from exc

    expected = hmac.new(
        _upload_signing_key(),
        body.encode("ascii"),
        hashlib.sha256,
    ).digest()
    provided = _b64url_decode(signature)
    if not hmac.compare_digest(expected, provided):
        raise ValueError("Invalid upload token signature")

    payload = json.loads(_b64url_decode(body).decode("utf-8"))
    if int(payload.get("exp", 0)) < int(datetime.now(timezone.utc).timestamp()):
        raise ValueError("Upload token expired")
    blob_name = str(payload.get("blob") or "")
    if not blob_name or ".." in blob_name or blob_name.startswith("/"):
        raise ValueError("Invalid blob name in token")
    return {
        "blob_name": blob_name,
        "content_type": str(payload.get("ct") or "application/octet-stream"),
        "user_id": str(payload.get("uid") or ""),
    }


def write_local_blob(blob_name: str, data: bytes) -> Path:
    root = media_root()
    target = (root / blob_name).resolve()
    if not str(target).startswith(str(root)):
        raise ValueError("Invalid media path")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    logger.info("local_blob_written path=%s bytes=%s", target, len(data))
    return target
