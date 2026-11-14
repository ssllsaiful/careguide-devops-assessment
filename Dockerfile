# ==============================================================================
# Stage 1: Build stage - Install and build dependencies
# ==============================================================================
FROM python:3.12.8-alpine3.21 AS builder

# Set build-time environment flags
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Install build dependencies 
RUN apk add --no-cache gcc musl-dev libffi-dev

COPY requirements.txt .

# Install dependencies into isolated installation prefix
RUN pip install --prefix=/install --no-warn-script-location -r requirements.txt

# ==============================================================================
# Stage 2: Runtime stage - Minimal attack surface runtime image
# ==============================================================================
FROM python:3.12.8-alpine3.21 AS runtime

# OpenContainers Initiative (OCI) standard labels
LABEL org.opencontainers.image.title="devops-task-service" \
      org.opencontainers.image.description="Production-grade observable microservice for CareGuide DevOps assessment" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="CareGuide DevOps Candidate" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="CareGuide"

# Set runtime environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    LOG_LEVEL=INFO \
    ENVIRONMENT=production \
    APP_VERSION=1.0.0 \
    PATH="/usr/local/bin:$PATH"

WORKDIR /app

# Create unprivileged system group & user (UID/GID 10001)
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup -h /app -s /sbin/nologin

# Copy installed Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy application source code
COPY --chown=appuser:appgroup app /app/app

# Enforce least-privilege non-root execution
USER 10001:10001

EXPOSE 8080

# Container health check probe
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/health" > /dev/null || exit 1

# Execute application via main module
ENTRYPOINT ["python", "-m", "app.main"]
CMD []
