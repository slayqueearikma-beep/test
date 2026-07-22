"""Transactional email delivery with production SMTP and safe development fallback."""

from __future__ import annotations

import logging
import re
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger("margem.email")

# Redact reset/verify tokens from log previews so they cannot be scraped from logs.
_TOKEN_RE = re.compile(r"(token=)([A-Za-z0-9_\-]{8,})", re.IGNORECASE)
_BEARERISH_RE = re.compile(r"\b([A-Za-z0-9_\-]{24,})\b")


def _safe_preview(text: str, limit: int = 200) -> str:
    redacted = _TOKEN_RE.sub(r"\1[REDACTED]", text)
    # Avoid dumping long opaque secrets in the middle of bodies.
    if "token" in text.lower() or "reset" in text.lower() or "verify" in text.lower():
        redacted = _BEARERISH_RE.sub("[REDACTED]", redacted)
    return redacted.replace("\n", " ")[:limit]


class EmailService:
    def send(self, *, to: str, subject: str, text_body: str, html_body: str | None = None) -> dict:
        """Send email. Never raises to callers — SMTP outages are logged and returned."""
        if not settings.smtp_host:
            logger.info(
                "email_dev_fallback to=%s subject=%s body=%s",
                to,
                subject,
                _safe_preview(text_body),
            )
            return {"delivered": False, "mode": "log", "preview": _safe_preview(text_body)}

        message = EmailMessage()
        message["From"] = settings.smtp_from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(text_body)
        if html_body:
            message.add_alternative(html_body, subtype="html")

        try:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
                if settings.smtp_use_tls:
                    smtp.starttls()
                if settings.smtp_username:
                    smtp.login(settings.smtp_username, settings.smtp_password)
                smtp.send_message(message)
        except (OSError, smtplib.SMTPException) as exc:
            logger.exception("email_send_failed to=%s subject=%s error=%s", to, subject, exc)
            return {"delivered": False, "mode": "smtp_error", "error": type(exc).__name__}

        logger.info("email_sent to=%s subject=%s", to, subject)
        return {"delivered": True, "mode": "smtp"}


email_service = EmailService()
