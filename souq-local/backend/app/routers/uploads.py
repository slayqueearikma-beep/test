from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import get_current_user
from app.config import settings
from app.models import User
from app.schemas import PresignRequest, PresignResponse

router = APIRouter(prefix="/uploads", tags=["uploads"])


@router.post("/presign", response_model=PresignResponse)
async def presign_upload(
    payload: PresignRequest,
    user: User = Depends(get_current_user),
) -> PresignResponse:
    if not settings.azure_storage_connection_string:
        # Dev fallback: return placeholder URLs
        blob_name = f"{user.id}/{uuid4()}-{payload.filename}"
        return PresignResponse(
            upload_url=f"https://dev.local/upload/{blob_name}",
            public_url=f"https://dev.local/media/{blob_name}",
        )

    try:
        from azure.storage.blob import BlobSasPermissions, generate_blob_sas
        from azure.storage.blob.aio import BlobServiceClient
        from datetime import datetime, timedelta, timezone

        blob_name = f"{user.id}/{uuid4()}-{payload.filename}"
        async with BlobServiceClient.from_connection_string(
            settings.azure_storage_connection_string
        ) as client:
            container = client.get_container_client(settings.azure_storage_container)
            blob_client = container.get_blob_client(blob_name)

            account_name = client.account_name
            sas = generate_blob_sas(
                account_name=account_name,
                container_name=settings.azure_storage_container,
                blob_name=blob_name,
                account_key=client.credential.account_key,
                permission=BlobSasPermissions(write=True, create=True),
                expiry=datetime.now(timezone.utc) + timedelta(minutes=15),
            )

            return PresignResponse(
                upload_url=f"{blob_client.url}?{sas}",
                public_url=blob_client.url,
            )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage service unavailable",
        ) from exc
