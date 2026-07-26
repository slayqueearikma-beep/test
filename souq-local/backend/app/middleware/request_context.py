"""Attach request_id and structured access logs."""

from __future__ import annotations

import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("margem.access")


def _safe_log_path(path: str) -> str:
    """Keep short-lived bearer upload tokens out of centralized access logs."""
    if path.startswith("/uploads/local/"):
        return "/uploads/local/[REDACTED]"
    return path


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = request_id
        started = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "request completed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": _safe_log_path(request.url.path),
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        return response
