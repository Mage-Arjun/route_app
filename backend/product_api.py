"""First-class delivery product API.

The original API remains available for the imported occupancy demo. This
router owns customers, routes, trips, approvals, POD, profile and analytics so
the Flutter client has one coherent contract for the complete workflow.
"""

from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from auth import current_user, hash_password, require_admin, require_driver, require_operator, verify_password
from config import settings
from database import get_db
from events import event_engine
from models import Customer, Event, ProofOfDelivery, Route, RouteChange, RouteStop, Trip, TripStop, User, Vehicle
from schemas import (
    CustomerCreate,
    CustomerUpdate,
    ProfileUpdate,
    ReorderStopsRequest,
    RegisterRequest,
    RouteChangeCreate,
    RouteCreate,
    RouteStopCreate,
    RouteUpdate,
    TripCreate,
    TripStopUpdate,
)
from state import utcnow


router = APIRouter()
UPLOAD_ROOT = Path(__file__).resolve().parent / "data" / "uploads"
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
MAX_UPLOAD_BYTES = 8 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _user_json(user: User | None):
    if not user:
        return None
    return {"id": user.id, "email": user.email, "role": user.role, "status": user.status}


def _customer_json(item: Customer):
    return {
        "id": item.id,
        "code": item.code,
        "name": item.name,
        "contact_name": item.contact_name,
        "phone": item.phone,
        "email": item.email,
        "address": item.address,
        "latitude": item.latitude,
        "longitude": item.longitude,
        "service_notes": item.service_notes,
        "status": item.status,
        "created_at": item.created_at,
        "updated_at": item.updated_at,
    }


def _route_json(db: Session, item: Route, include_stops: bool = True):
    driver = db.get(User, item.assigned_driver_id) if item.assigned_driver_id else None
    vehicle = db.get(Vehicle, item.assigned_vehicle_id) if item.assigned_vehicle_id else None
    result = {
        "id": item.id,
        "code": item.code,
        "name": item.name,
        "description": item.description,
        "status": item.status,
        "assigned_driver_id": item.assigned_driver_id,
        "assigned_vehicle_id": item.assigned_vehicle_id,
        "version": item.version,
        "created_at": item.created_at,
        "updated_at": item.updated_at,
        "assigned_driver": _user_json(driver),
        "assigned_vehicle": None if not vehicle else {"id": vehicle.id, "identifier": vehicle.identifier, "name": vehicle.name, "status": vehicle.status},
    }
    if include_stops:
        stops = db.query(RouteStop).filter(RouteStop.route_id == item.id).order_by(RouteStop.sequence).all()
        result["stops"] = [_route_stop_json(db, stop) for stop in stops]
    return result


def _route_stop_json(db: Session, item: RouteStop):
    customer = db.get(Customer, item.customer_id)
    return {
        "id": item.id,
        "route_id": item.route_id,
        "customer_id": item.customer_id,
        "sequence": item.sequence,
        "planned_arrival_time": item.planned_arrival_time,
        "service_duration_mins": item.service_duration_mins,
        "notes": item.notes,
        "status": item.status,
        "customer": _customer_json(customer) if customer else None,
    }


def _trip_stop_json(db: Session, item: TripStop):
    customer = db.get(Customer, item.customer_id)
    pod = db.query(ProofOfDelivery).filter(ProofOfDelivery.trip_stop_id == item.id).first()
    return {
        "id": item.id,
        "trip_id": item.trip_id,
        "route_stop_id": item.route_stop_id,
        "customer_id": item.customer_id,
        "sequence": item.sequence,
        "arrival_time": item.arrival_time,
        "departure_time": item.departure_time,
        "status": item.status,
        "notes": item.notes,
        "driver_notes": item.driver_notes,
        "receiver_name": item.receiver_name,
        "failure_reason": item.failure_reason,
        "delivery_latitude": item.delivery_latitude,
        "delivery_longitude": item.delivery_longitude,
        "completed_at": item.completed_at,
        "customer": _customer_json(customer) if customer else None,
        "pod": None if not pod else {"id": pod.id, "receiver_name": pod.receiver_name, "notes": pod.notes, "photo_path": pod.photo_path, "captured_at": pod.captured_at},
    }


def _trip_json(db: Session, item: Trip, include_stops: bool = True):
    route = db.get(Route, item.route_id)
    driver = db.get(User, item.driver_id)
    vehicle = db.get(Vehicle, item.vehicle_id) if item.vehicle_id else None
    stops = db.query(TripStop).filter(TripStop.trip_id == item.id).order_by(TripStop.sequence).all()
    completed = sum(stop.status in {"completed", "failed", "skipped"} for stop in stops)
    result = {
        "id": item.id,
        "code": item.code,
        "route_id": item.route_id,
        "driver_id": item.driver_id,
        "vehicle_id": item.vehicle_id,
        "date": item.trip_date,
        "start_time": item.start_time,
        "end_time": item.end_time,
        "total_distance_km": item.total_distance_km,
        "completed_stops": completed,
        "total_stops": len(stops),
        "status": item.status,
        "created_at": item.created_at,
        "route": _route_json(db, route, include_stops=False) if route else None,
        "driver": _user_json(driver),
        "vehicle": None if not vehicle else {"id": vehicle.id, "identifier": vehicle.identifier, "name": vehicle.name, "status": vehicle.status},
    }
    if include_stops:
        result["trip_stops"] = [_trip_stop_json(db, stop) for stop in stops]
    return result


def _change_json(db: Session, item: RouteChange):
    route = db.get(Route, item.route_id)
    customer = db.get(Customer, item.customer_id) if item.customer_id else None
    requested = db.get(User, item.requested_by_id)
    approved = db.get(User, item.approved_by_id) if item.approved_by_id else None
    return {
        "id": item.id,
        "route_id": item.route_id,
        "customer_id": item.customer_id,
        "recommended_sequence": item.recommended_sequence,
        "additional_distance_km": item.additional_distance_km,
        "additional_time_mins": item.additional_time_mins,
        "change_type": item.change_type,
        "reason": item.reason,
        "status": item.status,
        "requested_by_id": item.requested_by_id,
        "approved_by_id": item.approved_by_id,
        "requested_by": _user_json(requested),
        "approved_by": _user_json(approved),
        "customer": _customer_json(customer) if customer else None,
        "route": {"id": route.id, "code": route.code, "name": route.name} if route else None,
        "created_at": item.created_at,
        "decided_at": item.decided_at,
    }


async def _event(db: Session, event_type: str, entity_type: str, entity_id: int | None, actor_id: int, payload: dict):
    return await event_engine.publish(db, event_type=event_type, entity_type=entity_type, entity_id=entity_id, actor_id=actor_id, payload=payload, source="api")


def _assert_assignment(db: Session, route: Route, user: User):
    if user.role == "driver" and route.assigned_driver_id != user.id:
        raise HTTPException(403, "This route is not assigned to you")


@router.post("/auth/register")
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(409, "An account with this email already exists")
    user = User(email=email, password_hash=hash_password(body.password), role=body.role, status="active")
    db.add(user)
    db.commit()
    db.refresh(user)
    return _user_json(user)


@router.get("/users")
def users(role: str | None = None, search: str | None = None, db: Session = Depends(get_db), _: User = Depends(require_operator)):
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    if search:
        query = query.filter(User.email.ilike(f"%{search}%"))
    return [_user_json(user) for user in query.order_by(User.email).all()]


@router.put("/users/me")
def update_profile(body: ProfileUpdate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if body.email:
        email = body.email.strip().lower()
        existing = db.query(User).filter(User.email == email, User.id != user.id).first()
        if existing:
            raise HTTPException(409, "Email is already in use")
        user.email = email
    if body.new_password:
        if not body.current_password or not verify_password(body.current_password, user.password_hash):
            raise HTTPException(400, "Current password is incorrect")
        user.password_hash = hash_password(body.new_password)
    db.commit()
    db.refresh(user)
    return _user_json(user)


@router.get("/customers")
def customers(search: str | None = None, status: str | None = None, db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Customer)
    if search:
        term = f"%{search}%"
        query = query.filter(or_(Customer.code.ilike(term), Customer.name.ilike(term), Customer.phone.ilike(term)))
    if status:
        query = query.filter(Customer.status == status)
    return [_customer_json(item) for item in query.order_by(Customer.name).all()]


@router.post("/customers")
async def create_customer(body: CustomerCreate, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    if db.query(Customer).filter(Customer.code == body.code).first():
        raise HTTPException(409, "Customer code already exists")
    item = Customer(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await _event(db, "CUSTOMER_CREATED", "customer", item.id, user.id, {"code": item.code})
    return _customer_json(item)


@router.put("/customers/{customer_id}")
async def update_customer(customer_id: int, body: CustomerUpdate, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    item = db.get(Customer, customer_id)
    if not item:
        raise HTTPException(404, "Customer not found")
    for key, value in body.model_dump().items():
        setattr(item, key, value)
    db.commit()
    await _event(db, "CUSTOMER_UPDATED", "customer", item.id, user.id, {"code": item.code})
    return _customer_json(item)


def _validate_route_assignment(db: Session, driver_id: int | None, vehicle_id: int | None):
    if driver_id:
        driver = db.get(User, driver_id)
        if not driver or driver.role != "driver" or driver.status != "active":
            raise HTTPException(422, "Assigned user must be an active driver")
    if vehicle_id and not db.get(Vehicle, vehicle_id):
        raise HTTPException(404, "Assigned vehicle not found")


@router.get("/routes")
def routes(driver_id: int | None = None, status: str | None = None, search: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    query = db.query(Route)
    if user.role == "driver":
        query = query.filter(Route.assigned_driver_id == user.id)
    elif driver_id:
        query = query.filter(Route.assigned_driver_id == driver_id)
    if status:
        query = query.filter(Route.status == status)
    if search:
        term = f"%{search}%"
        query = query.filter(or_(Route.code.ilike(term), Route.name.ilike(term)))
    return [_route_json(db, item) for item in query.order_by(Route.name).all()]


@router.get("/routes/{route_id}")
def route_detail(route_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    item = db.get(Route, route_id)
    if not item:
        raise HTTPException(404, "Route not found")
    _assert_assignment(db, item, user)
    return _route_json(db, item)


@router.post("/routes")
async def create_route(body: RouteCreate, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    if db.query(Route).filter(Route.code == body.code).first():
        raise HTTPException(409, "Route code already exists")
    _validate_route_assignment(db, body.assigned_driver_id, body.assigned_vehicle_id)
    item = Route(**body.model_dump(), created_by_id=user.id)
    db.add(item)
    db.commit()
    db.refresh(item)
    await _event(db, "ROUTE_CREATED", "route", item.id, user.id, {"code": item.code})
    return _route_json(db, item)


@router.put("/routes/{route_id}")
async def update_route(route_id: int, body: RouteUpdate, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    item = db.get(Route, route_id)
    if not item:
        raise HTTPException(404, "Route not found")
    values = body.model_dump(exclude_unset=True)
    _validate_route_assignment(db, values.get("assigned_driver_id", item.assigned_driver_id), values.get("assigned_vehicle_id", item.assigned_vehicle_id))
    for key, value in values.items():
        setattr(item, key, value)
    item.version += 1
    db.commit()
    await _event(db, "ROUTE_UPDATED", "route", item.id, user.id, {"version": item.version})
    return _route_json(db, item)


@router.post("/routes/{route_id}/stops")
async def add_route_stop(route_id: int, body: RouteStopCreate, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    route = db.get(Route, route_id)
    if not route:
        raise HTTPException(404, "Route not found")
    if not db.get(Customer, body.customer_id):
        raise HTTPException(404, "Customer not found")
    if body.sequence <= 0:
        raise HTTPException(422, "Sequence must be positive")
    existing = db.query(RouteStop).filter(RouteStop.route_id == route_id).order_by(RouteStop.sequence.desc()).all()
    if any(stop.sequence == body.sequence for stop in existing):
        for stop in existing:
            if stop.sequence >= body.sequence:
                stop.sequence += 10000
        db.flush()
        for stop in existing:
            if stop.sequence >= 10000:
                stop.sequence -= 9999
    item = RouteStop(route_id=route_id, **body.model_dump())
    db.add(item)
    route.version += 1
    db.commit()
    db.refresh(item)
    await _event(db, "ROUTE_STOP_ADDED", "route", route_id, user.id, {"stop_id": item.id, "customer_id": item.customer_id})
    return _route_json(db, route)


@router.put("/routes/{route_id}/stops/reorder")
async def reorder_route_stops(route_id: int, body: ReorderStopsRequest, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    route = db.get(Route, route_id)
    stops = db.query(RouteStop).filter(RouteStop.route_id == route_id).all()
    if not route or len(stops) != len(body.stop_ids) or {stop.id for stop in stops} != set(body.stop_ids):
        raise HTTPException(422, "stop_ids must contain every stop on this route exactly once")
    for stop in stops:
        stop.sequence += 10000
    db.flush()
    positions = {stop_id: index for index, stop_id in enumerate(body.stop_ids, start=1)}
    for stop in stops:
        stop.sequence = positions[stop.id]
    route.version += 1
    db.commit()
    await _event(db, "ROUTE_STOPS_REORDERED", "route", route_id, user.id, {"stop_ids": body.stop_ids})
    return _route_json(db, route)


@router.get("/trips")
def trips(status: str | None = None, date: str | None = None, db: Session = Depends(get_db), user: User = Depends(current_user)):
    query = db.query(Trip)
    if user.role == "driver":
        query = query.filter(Trip.driver_id == user.id)
    if status:
        query = query.filter(Trip.status == status)
    if date:
        query = query.filter(func.date(Trip.trip_date) == date)
    return [_trip_json(db, item) for item in query.order_by(Trip.trip_date.desc()).all()]


@router.get("/trips/{trip_id}")
def trip_detail(trip_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    item = db.get(Trip, trip_id)
    if not item:
        raise HTTPException(404, "Trip not found")
    if user.role == "driver" and item.driver_id != user.id:
        raise HTTPException(403, "This trip is not assigned to you")
    return _trip_json(db, item)


@router.post("/trips")
async def create_trip(body: TripCreate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    route = db.get(Route, body.route_id)
    if not route:
        raise HTTPException(404, "Route not found")
    driver_id = user.id if user.role == "driver" else body.driver_id or route.assigned_driver_id
    if not driver_id:
        raise HTTPException(422, "A driver must be assigned before starting a trip")
    if user.role == "driver" and route.assigned_driver_id != user.id:
        raise HTTPException(403, "This route is not assigned to you")
    driver = db.get(User, driver_id)
    if not driver or driver.role != "driver":
        raise HTTPException(422, "Trip driver must be a driver account")
    vehicle_id = body.vehicle_id or route.assigned_vehicle_id
    if vehicle_id and not db.get(Vehicle, vehicle_id):
        raise HTTPException(404, "Trip vehicle not found")
    active = db.query(Trip).filter(Trip.route_id == route.id, Trip.status.in_(["planned", "active", "paused"])).first()
    if active:
        raise HTTPException(409, "This route already has an open trip")
    trip = Trip(code=f"TRIP-{datetime.now(timezone.utc):%Y%m%d}-{route.id}", route_id=route.id, driver_id=driver_id, vehicle_id=vehicle_id, trip_date=body.trip_date or utcnow(), status="active", start_time=utcnow())
    db.add(trip)
    db.flush()
    stops = db.query(RouteStop).filter(RouteStop.route_id == route.id, RouteStop.status == "active").order_by(RouteStop.sequence).all()
    for stop in stops:
        db.add(TripStop(trip_id=trip.id, route_stop_id=stop.id, customer_id=stop.customer_id, sequence=stop.sequence, notes=stop.notes))
    db.commit()
    db.refresh(trip)
    await _event(db, "TRIP_STARTED", "trip", trip.id, user.id, {"route_id": route.id, "driver_id": driver_id})
    return _trip_json(db, trip)


@router.put("/trips/{trip_id}/stops/{trip_stop_id}")
async def update_trip_stop(trip_id: int, trip_stop_id: int, body: TripStopUpdate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    trip = db.get(Trip, trip_id)
    stop = db.get(TripStop, trip_stop_id)
    if not trip or not stop or stop.trip_id != trip_id:
        raise HTTPException(404, "Trip stop not found")
    if user.role == "driver" and trip.driver_id != user.id:
        raise HTTPException(403, "This trip is not assigned to you")
    if trip.status not in {"active", "paused"}:
        raise HTTPException(409, f"Cannot update a {trip.status} trip")
    if body.action == "arrive":
        if stop.status not in {"pending", "arrived"}:
            raise HTTPException(409, "Stop has already been completed")
        stop.status = "arrived"
        stop.arrival_time = stop.arrival_time or utcnow()
    elif body.action == "complete":
        if stop.status not in {"arrived", "pending"}:
            raise HTTPException(409, "Stop has already been closed")
        if not body.receiver_name:
            raise HTTPException(422, "Receiver name is required to complete a stop")
        stop.status = "completed"
        stop.receiver_name = body.receiver_name
        stop.completed_at = utcnow()
        stop.departure_time = utcnow()
    else:
        if not body.failure_reason:
            raise HTTPException(422, "A reason is required for a skipped or failed stop")
        stop.status = "skipped" if body.action == "skip" else "failed"
        stop.failure_reason = body.failure_reason
        stop.completed_at = utcnow()
    stop.driver_notes = body.driver_notes
    stop.delivery_latitude = body.latitude
    stop.delivery_longitude = body.longitude
    db.commit()
    await _event(db, f"TRIP_STOP_{stop.status.upper()}", "trip_stop", stop.id, user.id, {"trip_id": trip_id, "status": stop.status})
    return _trip_stop_json(db, stop)


@router.put("/trips/{trip_id}/complete")
async def complete_trip(trip_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    trip = db.get(Trip, trip_id)
    if not trip:
        raise HTTPException(404, "Trip not found")
    if user.role == "driver" and trip.driver_id != user.id:
        raise HTTPException(403, "This trip is not assigned to you")
    if trip.status not in {"active", "paused"}:
        raise HTTPException(409, f"Cannot complete a {trip.status} trip")
    open_stops = db.query(TripStop).filter(TripStop.trip_id == trip.id, TripStop.status.in_(["pending", "arrived"])).count()
    if open_stops:
        raise HTTPException(409, f"{open_stops} stop(s) still need a result")
    trip.status = "completed"
    trip.end_time = utcnow()
    db.commit()
    await _event(db, "TRIP_COMPLETED", "trip", trip.id, user.id, {})
    return _trip_json(db, trip)


@router.put("/trips/{trip_id}/cancel")
async def cancel_trip(trip_id: int, db: Session = Depends(get_db), user: User = Depends(require_operator)):
    trip = db.get(Trip, trip_id)
    if not trip:
        raise HTTPException(404, "Trip not found")
    if trip.status in {"completed", "cancelled"}:
        raise HTTPException(409, "Trip is already closed")
    trip.status = "cancelled"
    trip.end_time = utcnow()
    db.commit()
    await _event(db, "TRIP_CANCELLED", "trip", trip.id, user.id, {})
    return _trip_json(db, trip)


@router.post("/trips/{trip_id}/stops/{trip_stop_id}/pod")
async def upload_pod(
    trip_id: int,
    trip_stop_id: int,
    receiver_name: str = Form(..., min_length=2, max_length=120),
    notes: str | None = Form(default=None),
    signature_data: str | None = Form(default=None),
    latitude: float | None = Form(default=None),
    longitude: float | None = Form(default=None),
    photo: UploadFile | None = File(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(current_user),
):
    trip = db.get(Trip, trip_id)
    stop = db.get(TripStop, trip_stop_id)
    if not trip or not stop or stop.trip_id != trip_id:
        raise HTTPException(404, "Trip stop not found")
    if user.role == "driver" and trip.driver_id != user.id:
        raise HTTPException(403, "This trip is not assigned to you")
    photo_path = None
    if photo:
        if photo.content_type not in ALLOWED_IMAGE_TYPES:
            raise HTTPException(415, "Only JPEG, PNG, or WebP photos are supported")
        content = await photo.read(MAX_UPLOAD_BYTES + 1)
        if len(content) > MAX_UPLOAD_BYTES:
            raise HTTPException(413, "Photo must be 8 MB or smaller")
        suffix = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[photo.content_type]
        safe_name = f"pod_{trip_id}_{trip_stop_id}_{uuid4().hex}{suffix}"
        (UPLOAD_ROOT / safe_name).write_bytes(content)
        photo_path = safe_name
    pod = db.query(ProofOfDelivery).filter(ProofOfDelivery.trip_stop_id == stop.id).first()
    if not pod:
        pod = ProofOfDelivery(trip_stop_id=stop.id, receiver_name=receiver_name, created_by_id=user.id)
        db.add(pod)
    pod.receiver_name = receiver_name
    pod.notes = notes
    pod.signature_data = signature_data
    pod.photo_path = photo_path or pod.photo_path
    pod.latitude = latitude
    pod.longitude = longitude
    pod.captured_at = utcnow()
    stop.status = "completed"
    stop.receiver_name = receiver_name
    stop.completed_at = utcnow()
    stop.departure_time = utcnow()
    stop.delivery_latitude = latitude
    stop.delivery_longitude = longitude
    db.commit()
    await _event(db, "PROOF_OF_DELIVERY_CAPTURED", "trip_stop", stop.id, user.id, {"trip_id": trip_id, "photo": bool(photo_path), "signature": bool(signature_data)})
    return _trip_stop_json(db, stop)


@router.get("/trips/{trip_id}/stops/{trip_stop_id}/pod/photo")
def pod_photo(trip_id: int, trip_stop_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    trip = db.get(Trip, trip_id)
    stop = db.get(TripStop, trip_stop_id)
    if not trip or not stop or stop.trip_id != trip_id:
        raise HTTPException(404, "Trip stop not found")
    if user.role == "driver" and trip.driver_id != user.id:
        raise HTTPException(403, "This trip is not assigned to you")
    pod = db.query(ProofOfDelivery).filter(ProofOfDelivery.trip_stop_id == stop.id).first()
    if not pod or not pod.photo_path:
        raise HTTPException(404, "No proof photo uploaded")
    path = UPLOAD_ROOT / Path(pod.photo_path).name
    if not path.is_file() or path.parent != UPLOAD_ROOT:
        raise HTTPException(404, "Proof photo not found")
    return FileResponse(path)


@router.get("/route-changes")
def route_changes(status: str | None = None, db: Session = Depends(get_db), _: User = Depends(require_operator)):
    query = db.query(RouteChange)
    if status:
        query = query.filter(RouteChange.status == status)
    return [_change_json(db, item) for item in query.order_by(RouteChange.created_at.desc()).all()]


@router.post("/route-changes")
async def create_route_change(body: RouteChangeCreate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    route = db.get(Route, body.route_id)
    if not route:
        raise HTTPException(404, "Route not found")
    if user.role == "driver":
        _assert_assignment(db, route, user)
    elif user.role not in {"admin", "operator"}:
        raise HTTPException(403, "Operator role required")
    item = RouteChange(**body.model_dump(), requested_by_id=user.id)
    db.add(item)
    db.commit()
    db.refresh(item)
    await _event(db, "ROUTE_CHANGE_REQUESTED", "route_change", item.id, user.id, {"route_id": route.id})
    return _change_json(db, item)


async def _decide_change(change_id: int, approved: bool, db: Session, user: User):
    item = db.get(RouteChange, change_id)
    if not item:
        raise HTTPException(404, "Route change not found")
    if item.status != "pending":
        raise HTTPException(409, "Route change has already been decided")
    item.status = "approved" if approved else "rejected"
    item.approved_by_id = user.id
    item.decided_at = utcnow()
    db.commit()
    await _event(db, f"ROUTE_CHANGE_{item.status.upper()}", "route_change", item.id, user.id, {"route_id": item.route_id})
    return _change_json(db, item)


@router.put("/route-changes/{change_id}/approve")
async def approve_change(change_id: int, db: Session = Depends(get_db), user: User = Depends(require_admin)):
    return await _decide_change(change_id, True, db, user)


@router.put("/route-changes/{change_id}/reject")
async def reject_change(change_id: int, db: Session = Depends(get_db), user: User = Depends(require_admin)):
    return await _decide_change(change_id, False, db, user)


@router.get("/analytics/dashboard")
def dashboard_analytics(db: Session = Depends(get_db), _: User = Depends(require_operator)):
    trips_today = db.query(Trip).filter(func.date(Trip.trip_date) == datetime.now(timezone.utc).date().isoformat()).count()
    active_trips = db.query(Trip).filter(Trip.status.in_(["active", "paused"])).count()
    total_stops = db.query(TripStop).count()
    completed_stops = db.query(TripStop).filter(TripStop.status == "completed").count()
    return {
        "total_routes": db.query(Route).count(),
        "total_customers": db.query(Customer).filter(Customer.status == "active").count(),
        "total_drivers": db.query(User).filter(User.role == "driver", User.status == "active").count(),
        "total_vehicles": db.query(Vehicle).count(),
        "today_trips": trips_today,
        "active_trips": active_trips,
        "today_completed_stops": completed_stops,
        "today_pending_stops": max(total_stops - completed_stops, 0),
        "pending_approvals": db.query(RouteChange).filter(RouteChange.status == "pending").count(),
        "completion_rate": round(completed_stops / total_stops, 4) if total_stops else 0,
        "active_alerts": db.query(Event).filter(Event.event_type.like("%ALERT%")).count(),
    }


@router.get("/analytics/routes/{route_id}")
def route_analytics(route_id: int, db: Session = Depends(get_db), _: User = Depends(require_operator)):
    route = db.get(Route, route_id)
    if not route:
        raise HTTPException(404, "Route not found")
    trips = db.query(Trip).filter(Trip.route_id == route_id).all()
    stops = db.query(RouteStop).filter(RouteStop.route_id == route_id).count()
    trip_ids = [trip.id for trip in trips]
    trip_stops = db.query(TripStop).filter(TripStop.trip_id.in_(trip_ids)).all() if trip_ids else []
    completed = sum(stop.status == "completed" for stop in trip_stops)
    return {"route_id": route_id, "route_code": route.code, "trips": len(trips), "completed_trips": sum(trip.status == "completed" for trip in trips), "total_stops": stops, "completed_stops": completed, "completion_rate": round(completed / len(trip_stops), 4) if trip_stops else 0}
