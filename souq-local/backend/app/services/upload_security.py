"""Upload filename/content-type checks and media URL allowlisting."""

from __future__ import annotations

import re
from pathlib import PurePosixPath
from urllib.parse import unquote, urlparse
from uuid import UUID

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}
_MAX_FILENAME_LENGTH = 120
_AZURE_BLOB_HOST_SUFFIX = ".blob.core.windows.net"


def sanitize_upload_filename(filename: str) -> str:
    name = PurePosixPath(filename).name
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name).strip("._")
    if not name:
        raise ValueError("Invalid filename")
    return name[:_MAX_FILENAME_LENGTH]


def validate_upload_content_type(content_type: str) -> None:
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise ValueError(f"Unsupported content type: {content_type}")


def validate_image_bytes(data: bytes, content_type: str) -> None:
    """Reject mislabeled/non-image uploads without trusting the HTTP header."""
    if content_type == "image/jpeg":
        valid = data.startswith(b"\xff\xd8\xff") and data.rstrip().endswith(b"\xff\xd9")
    elif content_type == "image/png":
        valid = data.startswith(b"\x89PNG\r\n\x1a\n")
    elif content_type == "image/gif":
        valid = data.startswith((b"GIF87a", b"GIF89a"))
    elif content_type == "image/webp":
        valid = len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP"
    else:
        valid = False
    if not valid:
        raise ValueError("Upload bytes do not match the declared image type")


def validate_media_url(
    url: str,
    *,
    owner_user_id: UUID | None = None,
    container: str,
    public_api_url: str | None = None,
) -> str:
    """Ensure image URLs point at Azure Blob or our local /media store.

    Empty string is allowed (no image). Rejects javascript:, data:, and foreign hosts.
    """
    value = (url or "").strip()
    if not value:
        return ""

    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Media URL must use http(s)")
    host = (parsed.hostname or "").lower()
    path = unquote(parsed.path or "")

    # Local media: {PUBLIC_API_URL}/media/{user_id}/...
    if public_api_url:
        base = urlparse(public_api_url.rstrip("/"))
        base_host = (base.hostname or "").lower()
        if base_host and host == base_host and path.startswith("/media/"):
            parts = [p for p in path.split("/") if p]
            # media / {user_id} / file...
            if len(parts) < 3 or parts[0] != "media":
                raise ValueError("Media URL path is not allowed")
            if owner_user_id is not None and parts[1] != str(owner_user_id):
                raise ValueError("Media URL must belong to the authenticated user")
            return value

    if parsed.scheme != "https":
        raise ValueError("Media URL must use https")
    if not host.endswith(_AZURE_BLOB_HOST_SUFFIX):
        raise ValueError("Media URL host is not allowed")

    # /{container}/{user_id}/...
    parts = [p for p in path.split("/") if p]
    if len(parts) < 2 or parts[0] != container:
        raise ValueError("Media URL path is not allowed")

    if owner_user_id is not None:
        if len(parts) < 3 or parts[1] != str(owner_user_id):
            raise ValueError("Media URL must belong to the authenticated user")

    return value
