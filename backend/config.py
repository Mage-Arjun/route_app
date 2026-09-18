from functools import lru_cache
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env", extra="ignore")
    APP_NAME: str = "RouteOS"
    APP_ENV: str = "development"
    SECRET_KEY: str = "dev-change-this-secret"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    DATABASE_URL: str = "sqlite:///./data/routeos.db"
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    TUI_BACKEND_URL: str = "http://127.0.0.1:8000"
    # Set these explicitly when running the optional terminal console.
    TUI_EMAIL: str = ""
    TUI_PASSWORD: str = ""
    GPS_STALE_THRESHOLD: int = 300
    AUTOMATION_ENABLED: bool = True
    # Production starts with an empty database. Enable explicitly for local
    # development only: SEED_DEMO_DATA=true.
    SEED_DEMO_DATA: bool = False
    # Creates only the three local quick-login accounts. It never creates
    # routes, customers, vehicles, trips, or other operational data.
    SEED_QUICK_ACCOUNTS: bool = False
    VERSION: str = "1.0.0"

    @property
    def is_production(self) -> bool:
        return self.APP_ENV.lower() == "production"

    def validate_runtime(self) -> None:
        if not self.is_production:
            return
        if self.SECRET_KEY == "dev-change-this-secret" or len(self.SECRET_KEY) < 32:
            raise RuntimeError("SECRET_KEY must be changed to a strong value in production")
        if self.TUI_PASSWORD in {"admin123", ""}:
            raise RuntimeError("TUI_PASSWORD must be changed in production")
        if self.ACCESS_TOKEN_EXPIRE_MINUTES <= 0:
            raise RuntimeError("ACCESS_TOKEN_EXPIRE_MINUTES must be positive")

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
