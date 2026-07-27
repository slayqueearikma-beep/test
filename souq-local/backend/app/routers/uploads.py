from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status

from app.auth import get_current_user
from app.config import settings
from app.limiter import limiter
from app.models import User
from app.schemas import PresignRequest, PresignResponse
from app.services.azure_storage import ensure_blob_container, extract_azure_account_key
from app.services.local_storage import (
    public_media_url,
    sign_upload_token,
    verify_upload_token,
    write_local_blob,
)
from app.services.upload_security import (
    sanitize_upload_filename,
    validate_image_bytes,
    validate_upload_content_type,
)

router = APIRouter(prefix="/uploads", tags=["uploads"])


def _presign_local(user: User, *, safe_filename: str, content_type: str) -> PresignResponse:
    blob_name = f"{user.id}/{uuid4()}-{safe_filename}"
    token = sign_upload_token(
        blob_name=blob_name,
        content_type=content_type,
        user_id=str(user.id),
    )
    base = settings.public_api_url.rstrip("/")
    return PresignResponse(
        upload_url=f"{base}/uploads/local/{token}",
        public_url=public_media_url(blob_name),
    )


async def _presign_azure(user: User, *, safe_filename: str, content_type: str) -> PresignResponse:
    from datetime import datetime, timedelta, timezone

    from azure.storage.blob import BlobSasPermissions, generate_blob_sas
    from azure.storage.blob.aio import BlobServiceClient

    conn = (settings.azure_storage_connection_string or "").strip().strip('"').strip("'")
    if not conn:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage is not configured. Set AZURE_STORAGE_CONNECTION_STRING on the API.",
        )

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
            public_url=blob_client.url,
        )


@router.post("/presign", response_model=PresignResponse)
@limiter.limit("20/minute")
async def presign_upload(
    request: Request,
    payload: PresignRequest,
    user: User = Depends(get_current_user),
) -> PresignResponse:
    try:
        safe_filename = sanitize_upload_filename(payload.filename)
        validate_upload_content_type(payload.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    try:
        if settings.storage_backend == "local":
            return _presign_local(
                user,
                safe_filename=safe_filename,
                content_type=payload.content_type,
            )
        return await _presign_azure(
            user,
            safe_filename=safe_filename,
            content_type=payload.content_type,
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
        hint = type(exc).__name__
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Storage service unavailable. Check AZURE_STORAGE_CONNECTION_STRING, "
                f"container '{settings.azure_storage_container}', and API network access to Azure ({hint})."
            ),
        ) from exc


@router.put("/local/{token}")
@limiter.limit("30/minute")
async def put_local_upload(
    token: str,
    request: Request,
    user: User = Depends(get_current_user),
) -> Response:
    """Receive a PUT from the mobile client for STORAGE_BACKEND=local."""
    if settings.storage_backend != "local":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Local storage disabled")

    try:
        meta = verify_upload_token(token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    if meta["user_id"] != str(user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Upload token belongs to another user")

    content_type = (request.headers.get("content-type") or meta["content_type"]).split(";")[0].strip()
    try:
        validate_upload_content_type(content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    body = await request.body()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty upload body")
    if len(body) > settings.max_upload_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Image too large")
    try:
        validate_image_bytes(body, content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    try:
        write_local_blob(meta["blob_name"], body)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    return Response(status_code=status.HTTP_201_CREATED)
