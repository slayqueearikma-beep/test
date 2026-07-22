from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.auth import get_current_user
from app.config import settings
from app.limiter import limiter
from app.models import User
from app.schemas import PresignRequest, PresignResponse
from app.services.azure_storage import ensure_blob_container, extract_azure_account_key
from app.services.upload_security import sanitize_upload_filename, validate_upload_content_type

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/presign", response_model=PresignResponse)
@limiter.limit("20/minute")
async def presign_upload(
    request: Request,
    payload: PresignRequest,
    user: User = Depends(get_current_user),
) -> PresignResponse:
    if settings.app_env in {"production", "prod"} and not settings.azure_storage_connection_string:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage is not configured. Set AZURE_STORAGE_CONNECTION_STRING.",
        )

    try:
        safe_filename = sanitize_upload_filename(payload.filename)
        validate_upload_content_type(payload.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    conn = (settings.azure_storage_connection_string or "").strip().strip('"').strip("'")
    if not conn:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage is not configured. Set AZURE_STORAGE_CONNECTION_STRING on the API.",
        )

    try:
        from azure.storage.blob import BlobSasPermissions, generate_blob_sas
        from azure.storage.blob.aio import BlobServiceClient
        from datetime import datetime, timedelta, timezone

        blob_name = f"{user.id}/{uuid4()}-{safe_filename}"
        async with BlobServiceClient.from_connection_string(conn) as client:
            container = client.get_container_client(settings.azure_storage_container)
            await ensure_blob_container(container)
            blob_client = container.get_blob_client(blob_name)

            account_name = client.account_name
            if not account_name:
                raise ValueError("Storage account name missing from connection string")
            account_key = extract_azure_account_key(client.credential)

            sas_write = generate_blob_sas(
                account_name=account_name,
                container_name=settings.azure_storage_container,
                blob_name=blob_name,
                account_key=account_key,
                permission=BlobSasPermissions(write=True, create=True),
                expiry=datetime.now(timezone.utc) + timedelta(minutes=15),
            )
            return PresignResponse(
                upload_url=f"{blob_client.url}?{sas_write}",
                # Durable URL without SAS — container is public-blob for media reads.
                public_url=blob_client.url,
            )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Storage configuration error: {exc}",
        ) from exc
    except Exception as exc:
        import logging

        logging.getLogger("margem.storage").exception("presign_failed")
        # Surface a actionable message without leaking secrets.
        hint = type(exc).__name__
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Storage service unavailable. Check AZURE_STORAGE_CONNECTION_STRING, "
                f"container '{settings.azure_storage_container}', and API network access to Azure ({hint})."
            ),
        ) from exc
