"""Optional Azure Application Insights / OpenTelemetry wiring."""

from __future__ import annotations

import logging
import os

logger = logging.getLogger("margem.telemetry")


def configure_telemetry() -> None:
    """Enable Azure Monitor when APPLICATIONINSIGHTS_CONNECTION_STRING is present.

    The SDK is optional so local/dev images stay lean. Production ACA images
    should install `azure-monitor-opentelemetry` (see requirements-telemetry.txt)
    or rely on platform log shipping of JSON stdout.
    """
    connection = (os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING") or "").strip()
    if not connection:
        return
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor
    except ImportError:
        logger.warning(
            "APPLICATIONINSIGHTS_CONNECTION_STRING is set but azure-monitor-opentelemetry "
            "is not installed — shipping structured JSON logs only"
        )
        return
    try:
        configure_azure_monitor(connection_string=connection)
        logger.info("azure_monitor_configured")
    except Exception:  # pragma: no cover - never block boot on APM
        logger.exception("azure_monitor_configure_failed")
