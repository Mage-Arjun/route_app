from pathlib import Path
from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from config import settings

# Resolve the demo SQLite database from this backend package, not from the
# caller's current working directory. This prevents a second empty database
# when somebody starts Uvicorn from the project root or another shell.
database_url = settings.DATABASE_URL
if database_url.startswith("sqlite:///./"):
    relative_path = database_url.removeprefix("sqlite:///./")
    database_url = f"sqlite:///{Path(__file__).resolve().parent / relative_path}"

if database_url.startswith("sqlite"):
    if "///" in database_url:
        Path(database_url.split("///", 1)[-1]).parent.mkdir(parents=True, exist_ok=True)
    engine = create_engine(database_url, connect_args={"check_same_thread": False}, pool_pre_ping=True)
else:
    engine = create_engine(database_url.replace("postgres://", "postgresql://", 1), pool_pre_ping=True, pool_size=5)

if database_url.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(connection, _record):
        cursor = connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

class Base(DeclarativeBase):
    pass

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db() -> None:
    from models import BaseModel  # noqa: F401
    Base.metadata.create_all(bind=engine)
