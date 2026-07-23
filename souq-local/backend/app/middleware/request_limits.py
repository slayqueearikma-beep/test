"""Hard-cap request body size, including chunked transfers without Content-Length."""

from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

from app.config import settings


class RequestSizeLimitMiddleware:
    """Pure ASGI middleware — BaseHTTPMiddleware cannot safely replay request bodies."""

    def __init__(self, app: ASGIApp, max_bytes: int | None = None) -> None:
        self.app = app
        self._max_bytes_override = max_bytes

    @property
    def max_bytes(self) -> int:
        if self._max_bytes_override is not None:
            return self._max_bytes_override
        return settings.max_request_body_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        max_bytes = self.max_bytes
        path = scope.get("path") or ""
        if isinstance(path, bytes):
            path = path.decode("latin-1", errors="ignore")
        if path.startswith("/uploads/local"):
            max_bytes = max(max_bytes, int(getattr(settings, "max_upload_bytes", 8_388_608)))

        headers = {k.decode("latin-1").lower(): v.decode("latin-1") for k, v in scope.get("headers", [])}
        content_length = headers.get("content-length")
        if content_length is not None:
            try:
                if int(content_length) > max_bytes:
                    response = JSONResponse(status_code=413, content={"detail": "Request body too large"})
                    await response(scope, receive, send)
                    return
            except ValueError:
                response = JSONResponse(status_code=400, content={"detail": "Invalid Content-Length"})
                await response(scope, receive, send)
                return

        body = bytearray()
        more_body = True
        while more_body:
            message = await receive()
            if message["type"] != "http.request":
                async def passthrough_receive():
                    return message

                await self.app(scope, passthrough_receive, send)
                return
            chunk = message.get("body", b"")
            if chunk:
                body.extend(chunk)
                if len(body) > max_bytes:
                    response = JSONResponse(status_code=413, content={"detail": "Request body too large"})
                    await response(scope, receive, send)
                    return
            more_body = bool(message.get("more_body", False))

        body_bytes = bytes(body)
        sent = False

        async def replay_receive() -> dict:
            nonlocal sent
            if not sent:
                sent = True
                return {"type": "http.request", "body": body_bytes, "more_body": False}
            return {"type": "http.request", "body": b"", "more_body": False}

        await self.app(scope, replay_receive, send)
