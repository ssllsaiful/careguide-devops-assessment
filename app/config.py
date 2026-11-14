import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration read strictly from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    port: int = 8080
    log_level: str = "INFO"
    environment: str = "development"
    app_version: str = "1.0.0"
    app_name: str = "devops-task-service"


# Cached singleton settings instance
settings = Settings()
