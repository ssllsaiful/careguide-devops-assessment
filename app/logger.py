import json
import logging
import sys
from datetime import datetime, timezone
from app.config import settings


class JSONFormatter(logging.Formatter):
    """Custom JSON formatter producing structured log entries for stdout."""

    def format(self, record: logging.LogRecord) -> str:
        log_payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "service": settings.app_name,
            "environment": settings.environment,
            "version": settings.app_version,
        }

        # Include extra contextual fields if present in record.__dict__
        for key in ("http_method", "http_path", "http_status", "duration_ms", "client_ip", "event"):
            if hasattr(record, key):
                log_payload[key] = getattr(record, key)

        if record.exc_info:
            log_payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_payload)


def setup_logger(name: str = "app") -> logging.Logger:
    """Configures and returns a logger emitting JSON to stdout."""
    logger = logging.getLogger(name)

    # Convert string log level from settings
    level = getattr(logging, settings.log_level.upper(), logging.INFO)
    logger.setLevel(level)

    # Avoid duplicate handlers if setup_logger is called repeatedly
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(level)
        handler.setFormatter(JSONFormatter())
        logger.addHandler(handler)
        logger.propagate = False

    return logger


logger = setup_logger("app")
