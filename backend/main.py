import os
import logging
from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from sqlalchemy import text

from database import get_db
from config import settings
import models
from auth import authenticate_user, create_access_token, get_current_user, get_admin_user
import schemas

from routers import users, customers, vehicles, routes, trips, analytics
from typing import Dict

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

# ── Ensure uploads directory exists ──────────────────────────────────────────
UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)

# ── App Factory ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Route App API",
    description="Production-ready Distributor Route Management System",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global Exception Handler ──────────────────────────────────────────────────
@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception on %s %s: %s", request.method, request.url.path, exc)
    return JSONResponse(
        status_code=500,
        content={"detail": "An internal server error occurred. Please try again later."},
    )

# ── Static file serving (Proof-of-Delivery photos) ───────────────────────────
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(users.router)
app.include_router(customers.router)
app.include_router(vehicles.router)
app.include_router(routes.router)
app.include_router(trips.router)
app.include_router(analytics.router)


# ── Auth Endpoints ────────────────────────────────────────────────────────────
@app.post("/auth/login", response_model=schemas.Token)
async def login(login_req: schemas.LoginRequest, db: Session = Depends(get_db)):
    from fastapi import HTTPException, status
    user = authenticate_user(db, login_req.email, login_req.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    token = create_access_token(data={"sub": str(user.id)})
    return schemas.Token(
        access_token=token,
        token_type="bearer",
        user=schemas.UserOut.model_validate(user)
    )


@app.post("/auth/register", response_model=schemas.UserOut, status_code=201)
async def register_driver(user_in: schemas.DriverRegisterRequest, db: Session = Depends(get_db)):
    """Public endpoint — driver self-registration. Account starts as 'pending' until admin approves."""
    from fastapi import HTTPException
    from auth import get_password_hash
    existing = db.query(models.User).filter(models.User.email == user_in.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = models.User(
        name=user_in.name,
        email=user_in.email,
        password_hash=get_password_hash(user_in.password),
        role="driver",
        phone=user_in.phone,
        status="pending",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ── Live Location (in-memory store for real-time GPS tracking) ────────────────
# Structure: { driver_id: { lat, lng, timestamp, driver_name } }
_live_locations: Dict[int, dict] = {}


@app.post("/tracking/location")
async def push_location(
    body: schemas.LocationPush,
    current_user: models.User = Depends(get_current_user)
):
    """Driver pushes current GPS position. Stored in memory for live admin view."""
    _live_locations[current_user.id] = {
        "driver_id": current_user.id,
        "driver_name": current_user.name,
        "lat": body.lat,
        "lng": body.lng,
        "accuracy": body.accuracy,
        "trip_id": body.trip_id,
        "timestamp": body.timestamp,
    }
    return {"ok": True}


@app.get("/tracking/live")
async def get_live_locations(
    current_user: models.User = Depends(get_admin_user)
):
    """Admin fetches all live driver GPS positions."""
    return list(_live_locations.values())


# ── Health Check ──────────────────────────────────────────────────────────────
@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False
    return {
        "status": "ok" if db_ok else "degraded",
        "app": "Route App API",
        "version": "2.0.0",
        "environment": settings.ENV,
        "database": "connected" if db_ok else "disconnected",
        "uploads_dir": os.path.exists(UPLOADS_DIR),
    }


@app.get("/")
def root():
    return {
        "message": "Route App API v2.0 — Production Ready",
        "docs": "/docs",
        "health": "/health",
    }
