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


def validate_media_url(url: str, *, owner_user_id: UUID | None = None, container: str) -> str:
    """Ensure image URLs point at our Azure container (optional owner path prefix).

    Empty string is allowed (no image). Rejects javascript:, data:, and foreign hosts.
    """
    value = (url or "").strip()
    if not value:
        return ""

    parsed = urlparse(value)
    if parsed.scheme != "https":
        raise ValueError("Media URL must use https")
    host = (parsed.hostname or "").lower()
    if not host.endswith(_AZURE_BLOB_HOST_SUFFIX):
        raise ValueError("Media URL host is not allowed")

    path = unquote(parsed.path or "")
    # /{container}/{user_id}/...
    parts = [p for p in path.split("/") if p]
    if len(parts) < 2 or parts[0] != container:
        raise ValueError("Media URL path is not allowed")

    if owner_user_id is not None:
        if len(parts) < 3 or parts[1] != str(owner_user_id):
            raise ValueError("Media URL must belong to the authenticated user")

    return value
