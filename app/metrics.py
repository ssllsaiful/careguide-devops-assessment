import time
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    CollectorRegistry,
    REGISTRY,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

# Custom metrics with low cardinality labels
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total number of HTTP requests processed",
    ["method", "endpoint", "status"],
)

ERROR_COUNT = Counter(
    "http_request_errors_total",
    "Total number of HTTP requests resulting in 4xx or 5xx status codes",
    ["method", "endpoint", "status"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency histogram in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

APP_START_TIME = Gauge(
    "app_start_time_seconds",
    "Unix timestamp of application startup",
)

APP_START_TIME.set(time.time())


def get_metrics_payload() -> tuple[bytes, str]:
    """Generates and returns the latest Prometheus metrics in standard format."""
    return generate_latest(REGISTRY), CONTENT_TYPE_LATEST
