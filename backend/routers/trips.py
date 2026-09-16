import os
import uuid
import base64
import logging
from datetime import datetime, timezone, date as date_type
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session, joinedload
from database import get_db
from auth import get_current_user, get_admin_user
import models, schemas
from typing import List, Optional
from services.route_optimizer import haversine_km

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trips", tags=["trips"])

UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)


# ─── List Trips ──────────────────────────────────────────────────────────────

@router.get("/", response_model=List[schemas.TripOut])
def list_trips(
    date: Optional[date_type] = None,
    driver_id: Optional[int] = None,
    status: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    q = db.query(models.Trip).options(
        joinedload(models.Trip.driver),
        joinedload(models.Trip.vehicle).joinedload(models.Vehicle.assigned_driver),
        joinedload(models.Trip.route),
        joinedload(models.Trip.trip_stops).joinedload(models.TripStop.customer),
    )
    if current_user.role == "driver":
        q = q.filter(models.Trip.driver_id == current_user.id)
    if driver_id:
        q = q.filter(models.Trip.driver_id == driver_id)
    if date:
        q = q.filter(models.Trip.date == date)
    if status:
        q = q.filter(models.Trip.status == status)
    return q.order_by(models.Trip.created_at.desc()).offset(skip).limit(limit).all()


# ─── Start Trip ──────────────────────────────────────────────────────────────

@router.post("/", response_model=schemas.TripOut)
def start_trip(
    trip_in: schemas.TripCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    route = db.query(models.Route).options(
        joinedload(models.Route.stops).joinedload(models.RouteStop.customer)
    ).filter(models.Route.id == trip_in.route_id).first()
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    if current_user.role == "driver" and route.assigned_driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="This route is not assigned to you")

    existing = db.query(models.Trip).filter(
        models.Trip.route_id == trip_in.route_id,
        models.Trip.driver_id == current_user.id,
        models.Trip.date == datetime.now(timezone.utc).date(),
        models.Trip.status == "active",
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="You already have an active trip for this route today")

    active_stops = sorted(
        [s for s in route.stops if s.status == "active"],
        key=lambda x: x.sequence
    )

    trip = models.Trip(
        route_id=trip_in.route_id,
        driver_id=current_user.id,
        vehicle_id=trip_in.vehicle_id or route.assigned_vehicle_id,
        date=datetime.now(timezone.utc).date(),
        start_time=datetime.now(timezone.utc),
        total_stops=len(active_stops),
        status="active",
    )
    db.add(trip)
    db.flush()

    for stop in active_stops:
        ts = models.TripStop(
            trip_id=trip.id,
            route_stop_id=stop.id,
            customer_id=stop.customer_id,
            sequence=stop.sequence,
        )
        db.add(ts)

    db.commit()
    db.refresh(trip)
    trip = db.query(models.Trip).options(
        joinedload(models.Trip.driver),
        joinedload(models.Trip.vehicle).joinedload(models.Vehicle.assigned_driver),
        joinedload(models.Trip.route),
        joinedload(models.Trip.trip_stops).joinedload(models.TripStop.customer),
    ).filter(models.Trip.id == trip.id).first()
    return trip


# ─── Get Single Trip ─────────────────────────────────────────────────────────

@router.get("/{trip_id}", response_model=schemas.TripOut)
def get_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    trip = db.query(models.Trip).options(
        joinedload(models.Trip.driver),
        joinedload(models.Trip.vehicle).joinedload(models.Vehicle.assigned_driver),
        joinedload(models.Trip.route),
        joinedload(models.Trip.trip_stops).joinedload(models.TripStop.customer),
    ).filter(models.Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if current_user.role == "driver" and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    return trip


# ─── Update Trip Stop (with full PoD data) ───────────────────────────────────

@router.put("/{trip_id}/stops/{stop_id}", response_model=schemas.TripStopOut)
def update_trip_stop(
    trip_id: int,
    stop_id: int,
    update: schemas.TripStopUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if current_user.role == "driver" and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only update your own trips")

    ts = db.query(models.TripStop).filter(
        models.TripStop.id == stop_id,
        models.TripStop.trip_id == trip_id
    ).first()
    if not ts:
        raise HTTPException(status_code=404, detail="Trip stop not found")

    # Update base fields
    ts.status = update.status
    if update.notes is not None:
        ts.notes = update.notes
    if update.driver_notes is not None:
        ts.driver_notes = update.driver_notes

    # Update PoD fields
    if update.receiver_name is not None:
        ts.receiver_name = update.receiver_name
    if update.signature_data is not None:
        ts.signature_data = update.signature_data
    if update.photo_url is not None:
        ts.photo_url = update.photo_url
    if update.failure_reason is not None:
        ts.failure_reason = update.failure_reason
    if update.delivery_latitude is not None:
        ts.delivery_latitude = update.delivery_latitude
    if update.delivery_longitude is not None:
        ts.delivery_longitude = update.delivery_longitude

    # Set timing on terminal status
    terminal_statuses = ["completed", "skipped", "refused", "partial", "closed", "rescheduled"]
    if update.status in terminal_statuses:
        now = datetime.now(timezone.utc)
        ts.departure_time = now
        ts.completed_at = now
        if not ts.arrival_time:
            ts.arrival_time = now

    # Recalculate trip's completed stops count
    done_count = db.query(models.TripStop).filter(
        models.TripStop.trip_id == trip_id,
        models.TripStop.status.in_(terminal_statuses)
    ).count()
    trip.completed_stops = done_count

    # Recalculate running total distance using Haversine between completed stops
    completed_stops_ordered = db.query(models.TripStop).options(
        joinedload(models.TripStop.customer)
    ).filter(
        models.TripStop.trip_id == trip_id,
        models.TripStop.status.in_(terminal_statuses)
    ).order_by(models.TripStop.sequence).all()

    total_dist = 0.0
    prev_lat, prev_lng = None, None
    # Start from depot if route has depot coords
    if trip.route:
        route = db.query(models.Route).filter(models.Route.id == trip.route_id).first()
        if route and route.start_lat and route.start_lng:
            prev_lat, prev_lng = route.start_lat, route.start_lng

    for cstop in completed_stops_ordered:
        if cstop.customer and prev_lat is not None:
            c_lat, c_lng = cstop.customer.latitude, cstop.customer.longitude
            total_dist += haversine_km(prev_lat, prev_lng, c_lat, c_lng)
            prev_lat, prev_lng = c_lat, c_lng

    trip.total_distance_km = round(total_dist, 2)

    db.commit()
    db.refresh(ts)
    ts = db.query(models.TripStop).options(
        joinedload(models.TripStop.customer)
    ).filter(models.TripStop.id == stop_id).first()
    return ts


# ─── Upload Delivery Photo ───────────────────────────────────────────────────

@router.post("/{trip_id}/stops/{stop_id}/photo")
async def upload_stop_photo(
    trip_id: int,
    stop_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Upload a delivery photo for a trip stop. Returns the photo URL."""
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if current_user.role == "driver" and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    ts = db.query(models.TripStop).filter(
        models.TripStop.id == stop_id,
        models.TripStop.trip_id == trip_id
    ).first()
    if not ts:
        raise HTTPException(status_code=404, detail="Trip stop not found")

    # Validate file type
    allowed_types = {"image/jpeg", "image/png", "image/webp"}
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, and WebP images are accepted")

    # Save file
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else "jpg"
    filename = f"pod_{trip_id}_{stop_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(UPLOADS_DIR, filename)

    contents = await file.read()
    with open(filepath, "wb") as f:
        f.write(contents)

    photo_url = f"/uploads/{filename}"
    ts.photo_url = photo_url
    db.commit()

    return {"photo_url": photo_url, "message": "Photo uploaded successfully"}


# ─── Complete Trip ────────────────────────────────────────────────────────────

@router.put("/{trip_id}/complete")
def complete_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if current_user.role == "driver" and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only complete your own trips")
    trip.status = "completed"
    trip.end_time = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Trip completed", "total_distance_km": trip.total_distance_km}


# ─── Cancel Trip ─────────────────────────────────────────────────────────────

@router.put("/{trip_id}/cancel")
def cancel_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if current_user.role == "driver" and trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only cancel your own trips")
    if trip.status != "active":
        raise HTTPException(status_code=400, detail="Only active trips can be cancelled")
    trip.status = "cancelled"
    trip.end_time = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Trip cancelled"}
