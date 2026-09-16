import os
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SECRET_KEY: str = "dev-only-change-this-in-production"
    DATABASE_URL: str = "sqlite:///./route_app.db"
    ENV: str = "development"
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.ENV == "production"

    @property
    def is_sqlite(self) -> bool:
        return self.DATABASE_URL.startswith("sqlite")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
