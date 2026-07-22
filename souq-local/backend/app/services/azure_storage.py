"""Azure Blob helpers for presigned uploads."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger("margem.storage")


def extract_azure_account_key(credential: Any) -> str:
    """Return the account key from BlobServiceClient.credential across SDK versions.

    azure-storage-blob 12.x uses AzureNamedKeyCredential (``.named_key.key``),
    while older docs/examples use ``.account_key``. Using the wrong attribute
    raises AttributeError and surfaces as a generic "Storage service unavailable".
    """
    if credential is None:
        raise ValueError("Storage credential is missing")

    key = getattr(credential, "account_key", None)
    if isinstance(key, str) and key:
        return key

    named = getattr(credential, "named_key", None)
    if named is not None:
        named_key = getattr(named, "key", None)
        if isinstance(named_key, str) and named_key:
            return named_key

    direct = getattr(credential, "key", None)
    if isinstance(direct, str) and direct:
        return direct

    raise ValueError("Unable to read Azure storage account key from credential")


async def ensure_blob_container(container_client: Any) -> None:
    """Create the media container (public blob read) if missing; ensure public read if present.

    Product/profile image URLs are stored permanently in Postgres. Public blob access
    avoids embedding expiring SAS tokens in those URLs.
    """
    from azure.storage.blob import PublicAccess

    try:
        await container_client.create_container(public_access=PublicAccess.Blob)
        logger.info(
            "created_blob_container name=%s public_access=blob",
            getattr(container_client, "container_name", "?"),
        )
        return
    except Exception as exc:  # noqa: BLE001
        message = str(exc).lower()
        status = getattr(exc, "status_code", None) or getattr(
            getattr(exc, "response", None), "status_code", None
        )
        if not (
            status == 409
            or "containeralreadyexists" in message
            or "already exists" in message
        ):
            raise

    # Container exists — best-effort ensure anonymous blob read for durable URLs.
    try:
        await container_client.set_container_access_policy(
            signed_identifiers={},
            public_access=PublicAccess.Blob,
        )
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            "could_not_set_public_blob_access container=%s error=%s",
            getattr(container_client, "container_name", "?"),
            type(exc).__name__,
        )
