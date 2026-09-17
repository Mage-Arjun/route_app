from datetime import datetime, timezone
from math import asin, cos, radians, sin, sqrt

from fastapi import HTTPException
from sqlalchemy.orm import Session

from events import event_engine
from models import Assignment, Journey, Location, Person, Vehicle


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _distance_meters(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> float:
    """Haversine distance; used only for operational proximity checks."""
    earth_radius = 6_371_000.0
    lat1, lat2 = radians(a_lat), radians(b_lat)
    dlat = radians(b_lat - a_lat)
    dlon = radians(b_lon - a_lon)
    value = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return earth_radius * 2 * asin(sqrt(value))


async def person_enter_vehicle(
    db: Session, person: Person, vehicle: Vehicle, actor_id: int | None = None
):
    journey = db.get(Journey, vehicle.current_journey_id) if vehicle.current_journey_id else None
    if not journey:
        raise HTTPException(409, "Vehicle is not assigned to a journey")

    active = (
        db.query(Assignment)
        .filter(Assignment.person_id == person.id, Assignment.status == "active")
        .first()
    )
    if active:
        if active.vehicle_id == vehicle.id and active.journey_id == journey.id:
            return {"status": "already_assigned", "assignment_id": active.id}
        raise HTTPException(409, "Person already has an active assignment")

    person.current_vehicle_id = vehicle.id
    person.current_journey_id = journey.id
    person.status = "travelling"
    assignment = Assignment(
        person_id=person.id,
        journey_id=journey.id,
        vehicle_id=vehicle.id,
        status="active",
    )
    db.add(assignment)
    db.commit()
    await event_engine.publish(
        db,
        event_type="PERSON_ENTERED_VEHICLE",
        entity_type="person",
        entity_id=person.id,
        actor_id=actor_id,
        payload={"vehicle_id": vehicle.id, "journey_id": journey.id},
        source="command",
    )
    return {"status": "assigned", "assignment_id": assignment.id}


async def person_exit_vehicle(db: Session, person: Person, actor_id: int | None = None, *, unexpected: bool = False):
    old_vehicle = person.current_vehicle_id
    old_journey = person.current_journey_id
    assignment = (
        db.query(Assignment)
        .filter(Assignment.person_id == person.id, Assignment.status == "active")
        .order_by(Assignment.id.desc())
        .first()
    )
    if assignment:
        assignment.status = "closed"
        assignment.left_at = utcnow()
    person.current_vehicle_id = None
    person.current_journey_id = None
    person.status = "inside"
    db.commit()
    event = await event_engine.publish(
        db,
        event_type="PERSON_EXITED_VEHICLE",
        entity_type="person",
        entity_id=person.id,
        actor_id=actor_id,
        payload={"vehicle_id": old_vehicle, "journey_id": old_journey, "unexpected": unexpected},
        source="command",
    )
    if unexpected:
        from automation import automation_engine
        await automation_engine.evaluate_unexpected_exit(db, person, vehicle_id=old_vehicle, journey_id=old_journey)
    return event


async def start_journey(db: Session, journey: Journey, actor_id: int | None = None):
    if journey.status not in {"planned", "assigned"}:
        raise HTTPException(409, f"Cannot start journey in {journey.status} state")
    vehicle = db.get(Vehicle, journey.vehicle_id)
    if not vehicle:
        raise HTTPException(409, "Journey vehicle does not exist")
    if vehicle.current_journey_id and vehicle.current_journey_id != journey.id:
        raise HTTPException(409, "Vehicle is already assigned to another active journey")
    journey.status = "active"
    journey.started_at = utcnow()
    vehicle.current_journey_id = journey.id
    vehicle.status = "moving"
    db.commit()
    return await event_engine.publish(
        db,
        event_type="JOURNEY_STARTED",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        payload={"vehicle_id": vehicle.id},
        source="command",
    )


async def pause_journey(db: Session, journey: Journey, actor_id: int | None = None):
    if journey.status != "active":
        raise HTTPException(409, f"Cannot pause journey in {journey.status} state")
    journey.status = "paused"
    db.commit()
    return await event_engine.publish(
        db,
        event_type="JOURNEY_PAUSED",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        source="command",
    )


async def resume_journey(db: Session, journey: Journey, actor_id: int | None = None):
    if journey.status != "paused":
        raise HTTPException(409, f"Cannot resume journey in {journey.status} state")
    journey.status = "active"
    db.commit()
    return await event_engine.publish(
        db,
        event_type="JOURNEY_RESUMED",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        source="command",
    )


async def complete_journey(db: Session, journey: Journey, actor_id: int | None = None):
    if journey.status not in {"active", "paused", "arrived"}:
        raise HTTPException(409, f"Cannot complete journey in {journey.status} state")
    journey.status = "completed"
    journey.completed_at = utcnow()
    vehicle = db.get(Vehicle, journey.vehicle_id)
    if vehicle:
        vehicle.current_journey_id = None
        vehicle.status = "idle"
    for person in db.query(Person).filter(Person.current_journey_id == journey.id).all():
        person.current_journey_id = None
        person.current_vehicle_id = None
        person.status = "inside"
        for assignment in (
            db.query(Assignment)
            .filter(Assignment.person_id == person.id, Assignment.status == "active")
            .all()
        ):
            assignment.status = "closed"
            assignment.left_at = utcnow()
    db.commit()
    return await event_engine.publish(
        db,
        event_type="JOURNEY_COMPLETED",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        source="command",
    )


async def assign_vehicle(db: Session, journey: Journey, vehicle: Vehicle, actor_id: int | None = None):
    # Assignment is deliberately idempotent: refreshing an operator screen or
    # retrying a command must not turn an already-correct assignment into a
    # false conflict, including for an active journey.
    if journey.vehicle_id == vehicle.id and vehicle.current_journey_id == journey.id:
        return {"status": "already_assigned", "journey_id": journey.id, "vehicle_id": vehicle.id}
    if journey.status not in {"planned", "assigned"}:
        raise HTTPException(409, "Only planned or assigned journeys can change vehicles")
    if vehicle.current_journey_id and vehicle.current_journey_id != journey.id:
        raise HTTPException(409, "Vehicle is already assigned to another journey")
    old_vehicle = db.get(Vehicle, journey.vehicle_id)
    if old_vehicle and old_vehicle.id != vehicle.id:
        active_assignments = db.query(Assignment).filter(Assignment.vehicle_id == old_vehicle.id, Assignment.status == "active").all()
        if active_assignments:
            raise HTTPException(409, "Journey has active people assignments; unassign or move them first")
    journey.vehicle_id = vehicle.id
    journey.status = "assigned"
    vehicle.current_journey_id = journey.id
    if vehicle.status == "idle":
        vehicle.status = "assigned"
    if old_vehicle and old_vehicle.id != vehicle.id and old_vehicle.current_journey_id == journey.id:
        old_vehicle.current_journey_id = None
        old_vehicle.status = "idle"
    db.commit()
    return await event_engine.publish(
        db,
        event_type="VEHICLE_ASSIGNED",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        payload={"vehicle_id": vehicle.id, "previous_vehicle_id": old_vehicle.id if old_vehicle and old_vehicle.id != vehicle.id else None},
        source="command",
    )


async def set_destination(db: Session, journey: Journey, location: Location, actor_id: int | None = None):
    if journey.status in {"completed", "cancelled"}:
        raise HTTPException(409, "Completed or cancelled journeys cannot change destination")
    journey.destination_location_id = location.id
    db.commit()
    return await event_engine.publish(
        db,
        event_type="DESTINATION_SET",
        entity_type="journey",
        entity_id=journey.id,
        actor_id=actor_id,
        payload={"location_id": location.id},
        source="command",
    )


async def update_vehicle_location(
    db: Session,
    vehicle: Vehicle,
    latitude: float,
    longitude: float,
    actor_id: int | None = None,
):
    vehicle.latitude = latitude
    vehicle.longitude = longitude
    vehicle.last_seen = utcnow()
    vehicle.status = "moving" if vehicle.current_journey_id else "idle"

    # Associate a vehicle with a named operational location only when it is
    # genuinely close enough; the database remains the source of truth.
    nearest = None
    nearest_distance = None
    for location in db.query(Location).filter(Location.status == "active").all():
        distance = _distance_meters(latitude, longitude, location.latitude, location.longitude)
        if distance <= 100 and (nearest_distance is None or distance < nearest_distance):
            nearest, nearest_distance = location, distance
    vehicle.current_location_id = nearest.id if nearest else None
    db.commit()

    event = await event_engine.publish(
        db,
        event_type="VEHICLE_LOCATION_UPDATED",
        entity_type="vehicle",
        entity_id=vehicle.id,
        actor_id=actor_id,
        payload={
            "latitude": latitude,
            "longitude": longitude,
            "location_id": nearest.id if nearest else None,
        },
        source="gps",
    )

    journey = db.get(Journey, vehicle.current_journey_id) if vehicle.current_journey_id else None
    if journey and journey.status == "active" and journey.destination_location_id:
        destination = db.get(Location, journey.destination_location_id)
        if destination and _distance_meters(latitude, longitude, destination.latitude, destination.longitude) <= 100:
            journey.status = "arrived"
            journey.arrived_at = utcnow()
            db.commit()
            await event_engine.publish(
                db,
                event_type="JOURNEY_ARRIVED",
                entity_type="journey",
                entity_id=journey.id,
                actor_id=actor_id,
                payload={"vehicle_id": vehicle.id, "destination_id": destination.id},
                source="automation",
            )
    return event
