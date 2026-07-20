import logging

logger = logging.getLogger("margem.security")


def log_security_event(event: str, **details: object) -> None:
    logger.warning("security_event=%s %s", event, " ".join(f"{k}={v}" for k, v in details.items()))
