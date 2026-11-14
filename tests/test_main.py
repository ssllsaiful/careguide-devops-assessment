import pytest
from starlette.testclient import TestClient

from app.main import app
from app.config import Settings


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def test_root_endpoint(client):
    """Test GET / returns expected message, status, and version."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Hello from DevOps Task!"
    assert data["status"] == "running"
    assert "version" in data


def test_health_endpoint(client):
    """Test GET /health returns healthy status and uptime."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert "version" in data
    assert "environment" in data


def test_metrics_endpoint(client):
    """Test GET /metrics returns prometheus formatted data."""
    # First make a request to ensure counters are exercised
    client.get("/")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers.get("content-type", "")

    content = response.text
    assert "http_requests_total" in content
    assert "http_request_duration_seconds" in content


def test_metrics_error_tracking(client):
    """Test that a 404 response increments error count."""
    client.get("/non-existent-endpoint")
    metrics_res = client.get("/metrics")
    assert "http_request_errors_total" in metrics_res.text


def test_custom_settings(monkeypatch):
    """Test configuration override from environment variables."""
    monkeypatch.setenv("PORT", "9090")
    monkeypatch.setenv("LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("ENVIRONMENT", "staging")
    monkeypatch.setenv("APP_VERSION", "2.1.0")

    custom_settings = Settings()
    assert custom_settings.port == 9090
    assert custom_settings.log_level == "DEBUG"
    assert custom_settings.environment == "staging"
    assert custom_settings.app_version == "2.1.0"
