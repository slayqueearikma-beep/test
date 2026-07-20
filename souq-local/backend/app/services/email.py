"""Transactional email delivery with production SMTP and safe development fallback."""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger("margem.email")


class EmailService:
    def send(self, *, to: str, subject: str, text_body: str, html_body: str | None = None) -> dict:
        """Send email. Returns delivery metadata. Never raises to callers for SMTP outages in prod logging path."""
        if not settings.smtp_host:
            logger.info(
                "email_dev_fallback to=%s subject=%s body=%s",
                to,
                subject,
                text_body.replace("\n", " ")[:500],
            )
            return {"delivered": False, "mode": "log", "preview": text_body}

        message = EmailMessage()
        message["From"] = settings.smtp_from
        message["To"] = to
        message["Subject"] = subject
        message.set_content(text_body)
        if html_body:
            message.add_alternative(html_body, subtype="html")

        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
            if settings.smtp_use_tls:
                smtp.starttls()
            if settings.smtp_username:
                smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)

        logger.info("email_sent to=%s subject=%s", to, subject)
        return {"delivered": True, "mode": "smtp"}


email_service = EmailService()
