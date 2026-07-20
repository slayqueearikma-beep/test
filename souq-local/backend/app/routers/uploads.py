from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.auth import get_current_user
from app.config import settings
from app.limiter import limiter
from app.models import User
from app.schemas import PresignRequest, PresignResponse
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
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Storage not configured")

    try:
        safe_filename = sanitize_upload_filename(payload.filename)
        validate_upload_content_type(payload.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if not settings.azure_storage_connection_string:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage service unavailable in this environment",
        )

    try:
        from azure.storage.blob import BlobSasPermissions, generate_blob_sas
        from azure.storage.blob.aio import BlobServiceClient
        from datetime import datetime, timedelta, timezone

        blob_name = f"{user.id}/{uuid4()}-{safe_filename}"
        async with BlobServiceClient.from_connection_string(
            settings.azure_storage_connection_string
        ) as client:
            container = client.get_container_client(settings.azure_storage_container)
            blob_client = container.get_blob_client(blob_name)

            account_name = client.account_name
            sas_write = generate_blob_sas(
                account_name=account_name,
                container_name=settings.azure_storage_container,
                blob_name=blob_name,
                account_key=client.credential.account_key,
                permission=BlobSasPermissions(write=True, create=True),
                expiry=datetime.now(timezone.utc) + timedelta(minutes=15),
            )
            sas_read = generate_blob_sas(
                account_name=account_name,
                container_name=settings.azure_storage_container,
                blob_name=blob_name,
                account_key=client.credential.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=datetime.now(timezone.utc) + timedelta(days=3650),
            )

            return PresignResponse(
                upload_url=f"{blob_client.url}?{sas_write}",
                public_url=f"{blob_client.url}?{sas_read}",
            )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage service unavailable",
        ) from exc
