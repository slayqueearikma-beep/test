import logging
import re

logger = logging.getLogger("margem.security")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _mask_value(key: str, value: object) -> object:
    if key.lower() in {"email", "to", "recipient"} and isinstance(value, str) and "@" in value:
        local, _, domain = value.partition("@")
        if not local:
            return f"[redacted]@{domain}"
        return f"{local[0]}***@{domain}"
    if key.lower() in {"token", "access_token", "refresh_token", "password"}:
        return "[redacted]"
    if isinstance(value, str) and _EMAIL_RE.match(value):
        local, _, domain = value.partition("@")
        return f"{local[0]}***@{domain}"
    return value


def log_security_event(event: str, **details: object) -> None:
    safe = {k: _mask_value(k, v) for k, v in details.items()}
    logger.warning(
        "security_event=%s %s",
        event,
        " ".join(f"{k}={v}" for k, v in safe.items()),
    )
