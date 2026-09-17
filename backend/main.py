import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from database import init_db
from config import settings
from api import router
from product_api import router as product_router
from events import event_engine

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

async def _automation_loop(stop_event: asyncio.Event):
    from database import SessionLocal
    from automation import automation_engine

    while not stop_event.is_set():
        try:
            with SessionLocal() as db:
                await automation_engine.evaluate_all(db)
        except Exception:
            logging.getLogger("routeos.automation").exception("automation cycle failed")
        try:
            await asyncio.wait_for(stop_event.wait(), timeout=5.0)
        except asyncio.TimeoutError:
            pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate_runtime(); init_db()
    # Keep the product demo useful after importing the older activity data.
    # This is idempotent and only fills the new customer/route layer when it
    # has not been created yet.
    from database import SessionLocal
    from seed import seed_product_demo
    with SessionLocal() as db:
        seed_product_demo(db)
    event_engine.enabled = True
    stop_event = asyncio.Event()
    automation_task = asyncio.create_task(_automation_loop(stop_event))
    app.state.automation_task = automation_task
    try:
        yield
    finally:
        stop_event.set()
        await automation_task
        event_engine.subscribers.clear()

app = FastAPI(title=settings.APP_NAME, version=settings.VERSION, lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if not settings.is_production else [],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

@app.get("/health")
def health(): return {"status": "ok", "app": settings.APP_NAME, "version": settings.VERSION, "database": "configured"}

@app.get("/")
def root(): return {"name": settings.APP_NAME, "version": settings.VERSION, "docs": "/docs", "health": "/health"}

@app.middleware("http")
async def request_id(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Request-ID"] = request.headers.get("X-Request-ID", "routeos")
    return response

app.include_router(router)
app.include_router(product_router)
