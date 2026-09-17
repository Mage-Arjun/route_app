import asyncio
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import or_
from sqlalchemy.orm import Session
from database import get_db
from models import Alert, Event, Journey, Location, Person, User, Vehicle
from schemas import *
from auth import create_token, hash_password, require_admin, require_operator, require_driver, current_user, authenticate_token, verify_password
from events import event_engine
from state import update_vehicle_location
from automation import automation_engine
from commands import execute
from config import settings
from network import network_info

router = APIRouter()

def person_json(db, item):
    vehicle = db.get(Vehicle, item.current_vehicle_id) if item.current_vehicle_id else None
    journey = db.get(Journey, item.current_journey_id) if item.current_journey_id else None
    location = db.get(Location, item.current_location_id) if item.current_location_id else None
    return {"id": item.id, "identifier": item.identifier, "name": item.name, "status": item.status, "vehicle": vehicle.identifier if vehicle else None, "vehicle_id": item.current_vehicle_id, "journey": journey.identifier if journey else None, "journey_id": item.current_journey_id, "location": location.name if location else None, "location_id": item.current_location_id, "updated_at": item.updated_at}

def vehicle_json(db, item):
    journey = db.get(Journey, item.current_journey_id) if item.current_journey_id else None
    location = db.get(Location, item.current_location_id) if item.current_location_id else None
    count = db.query(Person).filter(Person.current_vehicle_id == item.id).count()
    return {"id": item.id, "identifier": item.identifier, "name": item.name, "type": item.type, "status": item.status, "latitude": item.latitude, "longitude": item.longitude, "location": location.name if location else None, "journey": journey.identifier if journey else None, "journey_id": item.current_journey_id, "people_count": count, "last_seen": item.last_seen, "updated_at": item.updated_at}

def journey_json(db, item):
    vehicle = db.get(Vehicle, item.vehicle_id); origin = db.get(Location, item.origin_location_id); destination = db.get(Location, item.destination_location_id) if item.destination_location_id else None
    people = db.query(Person).filter(Person.current_journey_id == item.id).all()
    return {"id": item.id, "identifier": item.identifier, "vehicle": vehicle.identifier if vehicle else None, "vehicle_id": item.vehicle_id, "people": [{"id": p.id, "identifier": p.identifier, "name": p.name} for p in people], "origin": origin.name if origin else None, "origin_id": item.origin_location_id, "destination": destination.name if destination else None, "destination_id": item.destination_location_id, "status": item.status, "started_at": item.started_at, "arrived_at": item.arrived_at, "completed_at": item.completed_at, "updated_at": item.updated_at}

async def broadcast_state_changed(entity_type: str | None = None, entity_id: int | None = None):
    await event_engine.broadcast({
        "type": "state_changed",
        "entity_type": entity_type,
        "entity_id": entity_id,
    })


def driver_state_json(db, user: User):
    person = db.get(Person, user.person_id) if user.person_id else None
    vehicle = db.get(Vehicle, person.current_vehicle_id) if person and person.current_vehicle_id else None
    journey = db.get(Journey, person.current_journey_id) if person and person.current_journey_id else None
    destination = db.get(Location, journey.destination_location_id) if journey and journey.destination_location_id else None
    origin = db.get(Location, journey.origin_location_id) if journey else None
    origin = db.get(Location, journey.origin_location_id) if journey else None
    people = db.query(Person).filter(Person.current_journey_id == journey.id).all() if journey else []
    return {
        "user": {"id": user.id, "email": user.email, "role": user.role, "status": user.status},
        "driver": None if not person else {"id": person.id, "identifier": person.identifier, "name": person.name, "status": person.status},
        "vehicle": None if not vehicle else vehicle_json(db, vehicle),
        "journey": None if not journey else {**journey_json(db, journey), "people": [{"id": p.id, "identifier": p.identifier, "name": p.name, "status": p.status} for p in people]},
        "destination": None if not destination else {"id": destination.id, "code": destination.code, "name": destination.name, "type": destination.type, "latitude": destination.latitude, "longitude": destination.longitude, "status": destination.status},
        "origin": None if not origin else {"id": origin.id, "code": origin.code, "name": origin.name, "type": origin.type, "latitude": origin.latitude, "longitude": origin.longitude, "status": origin.status},
        "origin": None if not origin else {"id": origin.id, "code": origin.code, "name": origin.name, "type": origin.type, "latitude": origin.latitude, "longitude": origin.longitude, "status": origin.status},
        "operational_status": "unassigned" if not journey else journey.status,
    }

@router.post("/auth/login", response_model=Token)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email.lower()).first()
    if not user or not verify_password(body.password, user.password_hash): raise HTTPException(401, "Invalid email or password")
    return Token(access_token=create_token(user), user=user)

@router.get("/auth/me", response_model=UserOut)
def me(user: User = Depends(current_user)): return user

@router.get("/driver/me")
def driver_me(db: Session = Depends(get_db), user: User = Depends(require_driver)):
    return driver_state_json(db, user)

@router.get("/people")
def people(search: str | None = None, status: str | None = None, db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Person)
    if search: query = query.filter(or_(Person.identifier.ilike(f"%{search}%"), Person.name.ilike(f"%{search}%")))
    if status: query = query.filter(Person.status == status)
    return [person_json(db, p) for p in query.order_by(Person.identifier).all()]

@router.post("/people")
async def create_person(body: PersonCreate, db: Session = Depends(require_operator), user: User = Depends(current_user)):
    if db.query(Person).filter(Person.identifier == body.identifier).first():
        raise HTTPException(409, "Person identifier already exists")
    item = Person(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await event_engine.publish(db, event_type="PERSON_CREATED", entity_type="person", entity_id=item.id, actor_id=user.id, payload={"identifier": item.identifier}, source="api")
    await broadcast_state_changed("person", item.id)
    return person_json(db, item)

@router.get("/vehicles")
def vehicles(status: str | None = None, db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Vehicle)
    if status: query = query.filter(Vehicle.status == status)
    return [vehicle_json(db, v) for v in query.order_by(Vehicle.identifier).all()]

@router.post("/vehicles")
async def create_vehicle(body: VehicleCreate, db: Session = Depends(require_operator), user: User = Depends(current_user)):
    if db.query(Vehicle).filter(Vehicle.identifier == body.identifier).first():
        raise HTTPException(409, "Vehicle identifier already exists")
    item = Vehicle(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await event_engine.publish(db, event_type="VEHICLE_CREATED", entity_type="vehicle", entity_id=item.id, actor_id=user.id, payload={"identifier": item.identifier}, source="api")
    await broadcast_state_changed("vehicle", item.id)
    return vehicle_json(db, item)

@router.post("/vehicles/{vehicle_id}/location")
async def vehicle_location(vehicle_id: int, body: LocationUpdate, db: Session = Depends(get_db), user: User = Depends(current_user)):
    vehicle = db.get(Vehicle, vehicle_id)
    if not vehicle: raise HTTPException(404, "Vehicle not found")
    if user.role == "driver":
        person = db.get(Person, user.person_id) if user.person_id else None
        if not person or person.current_vehicle_id != vehicle_id:
            raise HTTPException(403, "Driver is not assigned to this vehicle")
    elif user.role not in {"admin", "operator"}:
        raise HTTPException(403, "Operator role required")
    await update_vehicle_location(db, vehicle, body.latitude, body.longitude, user.id)
    await automation_engine.evaluate_vehicle(db, vehicle)
    await broadcast_state_changed("vehicle", vehicle.id)
    return vehicle_json(db, vehicle)

@router.get("/locations")
def locations(db: Session = Depends(get_db), _: User = Depends(current_user)):
    result = []
    for item in db.query(Location).order_by(Location.code).all():
        people_count = db.query(Person).filter(Person.current_location_id == item.id).count()
        vehicles_count = db.query(Vehicle).filter(Vehicle.current_location_id == item.id).count()
        result.append({"id": item.id, "code": item.code, "name": item.name, "type": item.type, "latitude": item.latitude, "longitude": item.longitude, "status": item.status, "people_count": people_count, "vehicles_count": vehicles_count})
    return result

@router.post("/locations")
async def create_location(body: LocationCreate, db: Session = Depends(require_operator), user: User = Depends(current_user)):
    if db.query(Location).filter(Location.code == body.code).first():
        raise HTTPException(409, "Location code already exists")
    item = Location(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await event_engine.publish(db, event_type="LOCATION_CREATED", entity_type="location", entity_id=item.id, actor_id=user.id, payload={"code": item.code}, source="api")
    await broadcast_state_changed("location", item.id)
    return item

@router.get("/journeys")
def journeys(status: str | None = None, db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Journey)
    if status: query = query.filter(Journey.status == status)
    return [journey_json(db, j) for j in query.order_by(Journey.id.desc()).all()]

@router.post("/journeys")
async def create_journey(body: JourneyCreate, db: Session = Depends(require_operator), user: User = Depends(current_user)):
    if not db.get(Vehicle, body.vehicle_id) or not db.get(Location, body.origin_location_id):
        raise HTTPException(404, "Vehicle or origin not found")
    if body.destination_location_id is not None and not db.get(Location, body.destination_location_id):
        raise HTTPException(404, "Destination location not found")
    if db.query(Journey).filter(Journey.identifier == body.identifier).first():
        raise HTTPException(409, "Journey identifier already exists")
    item = Journey(**body.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    await event_engine.publish(db, event_type="JOURNEY_CREATED", entity_type="journey", entity_id=item.id, actor_id=user.id, payload={"identifier": item.identifier}, source="api")
    await broadcast_state_changed("journey", item.id)
    return journey_json(db, item)

@router.get("/events", response_model=list[EventOut])
def events(entity_type: str | None = None, limit: int = Query(100, le=500), db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Event)
    if entity_type: query = query.filter(Event.entity_type == entity_type)
    return query.order_by(Event.timestamp.desc()).limit(limit).all()

@router.get("/alerts", response_model=list[AlertOut])
def alerts(status: str | None = "active", db: Session = Depends(get_db), _: User = Depends(current_user)):
    query = db.query(Alert)
    if status and status != "all": query = query.filter(Alert.status == status)
    return query.order_by(Alert.created_at.desc()).all()

@router.post("/commands")
async def command(body: CommandRequest, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if user.role == "driver":
        if body.command not in {"START_JOURNEY", "PAUSE_JOURNEY", "RESUME_JOURNEY", "STOP_JOURNEY"}:
            raise HTTPException(403, "Drivers may only control their assigned journey")
        person = db.get(Person, user.person_id) if user.person_id else None
        journey_id = body.payload.get("journey_id")
        if not person or not journey_id or person.current_journey_id != journey_id:
            raise HTTPException(403, "Journey is not assigned to this driver")
    elif user.role not in {"admin", "operator"}:
        raise HTTPException(403, "Operator role required")
    result = await execute(db, body, user.id)
    await broadcast_state_changed()
    return result

@router.get("/system/state")
def system_state(db: Session = Depends(get_db), _: User = Depends(current_user)):
    return {"people": [person_json(db, p) for p in db.query(Person).all()], "vehicles": [vehicle_json(db, v) for v in db.query(Vehicle).all()], "journeys": [journey_json(db, j) for j in db.query(Journey).all()], "alerts": [{"id": a.id, "severity": a.severity, "alert_type": a.alert_type, "message": a.message, "status": a.status, "created_at": a.created_at} for a in db.query(Alert).filter(Alert.status == "active").all()]}

@router.get("/system/status")
def system_status(db: Session = Depends(get_db), _: User = Depends(current_user)):
    return {"server": "online", "database": "connected", "event_engine": "running", "automation": "running" if automation_engine.enabled else "disabled", "websocket_clients": len(event_engine.subscribers), "last_event": event_engine.last_event_at, "version": settings.VERSION, "network": network_info()}

@router.get("/system/network")
def system_network(_: User = Depends(current_user)):
    return network_info()

@router.websocket("/ws")
async def websocket(socket: WebSocket):
    authorization = socket.headers.get("authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        await socket.close(code=1008, reason="Authentication required")
        return
    from database import SessionLocal
    try:
        with SessionLocal() as db:
            authenticate_token(token, db)
    except HTTPException:
        await socket.close(code=1008, reason="Invalid authentication credentials")
        return

    await socket.accept()
    queue: asyncio.Queue = asyncio.Queue()
    async def receive(message):
        await queue.put(message)
    event_engine.subscribe(receive)
    try:
        await socket.send_json({"type": "connected", "message": "RouteOS event stream ready"})
        while True:
            await socket.send_json(await queue.get())
    except WebSocketDisconnect:
        pass
    finally:
        event_engine.unsubscribe(receive)
