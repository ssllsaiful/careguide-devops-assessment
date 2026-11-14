import sys
import time
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI, Request, Response, status
from fastapi.responses import JSONResponse

from app.config import settings
from app.logger import logger
from app.metrics import (
    REQUEST_COUNT,
    ERROR_COUNT,
    REQUEST_LATENCY,
    APP_START_TIME,
    get_metrics_payload,
)

START_TIMESTAMP = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manages application lifecycle: startup and graceful shutdown on SIGTERM."""
    logger.info(
        f"Starting {settings.app_name} v{settings.app_version} on port {settings.port} "
        f"in {settings.environment} environment",
        extra={"event": "startup"},
    )
    APP_START_TIME.set(time.time())
    try:
        yield
    finally:
        logger.info(
            f"Graceful shutdown initiated for {settings.app_name}. Draining connections...",
            extra={"event": "shutdown"},
        )


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


@app.middleware("http")
async def metrics_and_logging_middleware(request: Request, call_next):
    """Middleware capturing request metrics and emitting structured JSON access logs."""
    start_time = time.perf_counter()
    raw_path = request.url.path
    method = request.method

    # Normalize path to prevent cardinality explosion in Prometheus & Loki
    # Known fixed routes: '/', '/health', '/metrics', '/docs', '/openapi.json'
    if raw_path in {"/", "/health", "/metrics", "/docs", "/openapi.json"}:
        endpoint = raw_path
    else:
        endpoint = "other"

    client_ip = request.client.host if request.client else "unknown"

    try:
        response: Response = await call_next(request)
        status_code = response.status_code
    except Exception as exc:
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        duration_sec = duration_ms / 1000.0

        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=500).inc()
        ERROR_COUNT.labels(method=method, endpoint=endpoint, status=500).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration_sec)

        logger.error(
            f"Unhandled exception during {method} {raw_path}: {exc}",
            exc_info=True,
            extra={
                "http_method": method,
                "http_path": raw_path,
                "http_status": 500,
                "duration_ms": duration_ms,
                "client_ip": client_ip,
                "event": "request_error",
            },
        )
        raise exc

    duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
    duration_sec = duration_ms / 1000.0

    # Record Prometheus metrics
    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=status_code).inc()
    if status_code >= 400:
        ERROR_COUNT.labels(method=method, endpoint=endpoint, status=status_code).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration_sec)

    # Emit structured JSON log to stdout
    log_level = "error" if status_code >= 500 else ("warning" if status_code >= 400 else "info")
    log_fn = getattr(logger, log_level, logger.info)
    log_fn(
        f"{method} {raw_path} completed with {status_code} in {duration_ms}ms",
        extra={
            "http_method": method,
            "http_path": raw_path,
            "http_status": status_code,
            "duration_ms": duration_ms,
            "client_ip": client_ip,
            "event": "http_request",
        },
    )

    return response


@app.get(
    "/",
    status_code=status.HTTP_200_OK,
    summary="Root Service Info",
    description="Returns service status and version information.",
)
async def root():
    return {
        "message": "Hello from DevOps Task!",
        "status": "running",
        "version": settings.app_version,
    }


@app.get(
    "/health",
    status_code=status.HTTP_200_OK,
    summary="Liveness and Readiness Probe",
    description="Health check endpoint for Kubernetes probes and load balancers.",
)
async def health():
    uptime = round(time.time() - START_TIMESTAMP, 2)
    return {
        "status": "healthy",
        "uptime_seconds": uptime,
        "version": settings.app_version,
        "environment": settings.environment,
    }


@app.get(
    "/metrics",
    summary="Prometheus Metrics",
    description="Exposes application and runtime metrics in Prometheus text format.",
)
async def metrics():
    data, content_type = get_metrics_payload()
    return Response(content=data, media_type=content_type)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.port,
        log_config=None,  # Suppress default uvicorn formatting in favor of our custom JSON logger
    )
