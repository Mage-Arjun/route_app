from fastapi import HTTPException
from sqlalchemy.orm import Session

from automation import automation_engine
from events import event_engine
from models import Alert, Journey, Location, Person, Vehicle
from schemas import CommandRequest
from state import (
    assign_vehicle,
    complete_journey,
    pause_journey,
    person_enter_vehicle,
    person_exit_vehicle,
    resume_journey,
    set_destination,
    start_journey,
)


async def execute(db: Session, request: CommandRequest, actor_id: int):
    payload = request.payload
    command = request.command

    if command in {"START_JOURNEY", "PAUSE_JOURNEY", "RESUME_JOURNEY", "STOP_JOURNEY"}:
        journey = db.get(Journey, payload.get("journey_id"))
        if not journey:
            raise HTTPException(404, "Journey not found")
        handlers = {
            "START_JOURNEY": start_journey,
            "PAUSE_JOURNEY": pause_journey,
            "RESUME_JOURNEY": resume_journey,
            "STOP_JOURNEY": complete_journey,
        }
        return await handlers[command](db, journey, actor_id)

    if command == "ASSIGN_PERSON":
        person = db.get(Person, payload.get("person_id"))
        vehicle = db.get(Vehicle, payload.get("vehicle_id"))
        if not person or not vehicle:
            raise HTTPException(404, "Person or vehicle not found")
        return await person_enter_vehicle(db, person, vehicle, actor_id)

    if command == "UNASSIGN_PERSON":
        person = db.get(Person, payload.get("person_id"))
        if not person:
            raise HTTPException(404, "Person not found")
        return await person_exit_vehicle(db, person, actor_id, unexpected=bool(payload.get("unexpected", False)))

    if command == "ASSIGN_VEHICLE":
        journey = db.get(Journey, payload.get("journey_id"))
        vehicle = db.get(Vehicle, payload.get("vehicle_id"))
        if not journey or not vehicle:
            raise HTTPException(404, "Journey or vehicle not found")
        return await assign_vehicle(db, journey, vehicle, actor_id)

    if command == "SET_DESTINATION":
        journey = db.get(Journey, payload.get("journey_id"))
        location = db.get(Location, payload.get("location_id"))
        if not journey or not location:
            raise HTTPException(404, "Journey or location not found")
        return await set_destination(db, journey, location, actor_id)

    if command == "CREATE_LOCATION":
        required = {"code", "name", "latitude", "longitude"}
        if not required.issubset(payload):
            raise HTTPException(422, "code, name, latitude and longitude are required")
        if db.query(Location).filter(Location.code == payload["code"]).first():
            raise HTTPException(409, "Location code already exists")
        try:
            latitude = float(payload["latitude"])
            longitude = float(payload["longitude"])
        except (TypeError, ValueError):
            raise HTTPException(422, "latitude and longitude must be numbers")
        location = Location(
            code=str(payload["code"]),
            name=str(payload["name"]),
            type=str(payload.get("type", "place")),
            latitude=latitude,
            longitude=longitude,
        )
        if not -90 <= location.latitude <= 90 or not -180 <= location.longitude <= 180:
            raise HTTPException(422, "Invalid coordinates")
        db.add(location)
        db.commit()
        db.refresh(location)
        await event_engine.publish(
            db,
            event_type="LOCATION_CREATED",
            entity_type="location",
            entity_id=location.id,
            actor_id=actor_id,
            payload={"code": location.code},
            source="command",
        )
        return {"status": "created", "location_id": location.id}

    if command == "RESOLVE_ALERT":
        alert = db.get(Alert, payload.get("alert_id"))
        if not alert:
            raise HTTPException(404, "Alert not found")
        if alert.status == "resolved":
            return {"status": "already_resolved", "alert_id": alert.id}
        from state import utcnow
        alert.status = "resolved"
        alert.resolved_by = actor_id
        alert.resolved_at = utcnow()
        db.commit()
        return await event_engine.publish(
            db,
            event_type="ALERT_RESOLVED",
            entity_type="alert",
            entity_id=alert.id,
            actor_id=actor_id,
            payload={"alert_id": alert.id},
            source="command",
        )

    if command in {"ENABLE_AUTOMATION", "DISABLE_AUTOMATION"}:
        automation_engine.enabled = command == "ENABLE_AUTOMATION"
        await event_engine.publish(
            db,
            event_type="AUTOMATION_ENABLED" if automation_engine.enabled else "AUTOMATION_DISABLED",
            entity_type="system",
            actor_id=actor_id,
            payload={"enabled": automation_engine.enabled},
            source="command",
        )
        return {"status": "ok", "automation_enabled": automation_engine.enabled}

    if command == "REFRESH_STATE":
        return {"status": "refreshed"}

    raise HTTPException(400, f"Unsupported command: {command}")
