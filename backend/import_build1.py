"""Import useful Build 1 data into the RouteOS operational model.

Build 1 was delivery-route oriented while RouteOS is activity/event oriented.
This importer deliberately translates concepts instead of copying its schema:

* customers -> tracked people + geocoded locations
* routes -> journeys
* route stops -> assignments
* pending route changes -> alerts
* trips and route history -> events

The source SQLite database is opened read-only. The import is idempotent by
email, identifier, and location code, so it is safe to run more than once.
"""

from __future__ import annotations

import argparse
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from database import SessionLocal, init_db
from models import Alert, Assignment, Customer, Event, Journey, Location, Person, ProofOfDelivery, Route, RouteChange, RouteStop, Trip, TripStop, User, Vehicle
from state import utcnow


DEFAULT_SOURCE = Path(__file__).resolve().parents[2] / "Build 1" / "backend" / "route_app.db"


def _rows(source: sqlite3.Connection, table: str) -> list[sqlite3.Row]:
    return source.execute(f'SELECT * FROM "{table}"').fetchall()


def _parse_datetime(value: object) -> datetime | None:
    if not value:
        return None
    text = str(value).replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _location(db: Session, code: str, name: str, latitude: float, longitude: float, kind: str) -> Location:
    item = db.query(Location).filter(Location.code == code).first()
    if item:
        return item
    item = Location(code=code, name=name, type=kind, latitude=latitude, longitude=longitude)
    db.add(item)
    db.flush()
    return item


def _user(db: Session, row: sqlite3.Row) -> User:
    email = str(row["email"]).lower()
    item = db.query(User).filter(User.email == email).first()
    # Preserve the meaningful Build 1 roles. Supervisors map to the new
    # operator capability set; administrators remain administrators.
    role = "admin" if row["role"] == "admin" else "operator" if row["role"] in {"supervisor", "operator"} else "driver"
    if item:
        # Reconcile an existing imported account instead of leaving the first
        # import's role/hash permanently stale.
        item.password_hash = row["password_hash"]
        item.role = role
        item.status = row["status"] or "active"
        return item
    item = User(
        email=email,
        password_hash=row["password_hash"],
        role=role,
        status=row["status"] or "active",
    )
    db.add(item)
    db.flush()
    return item


def import_build1(source_path: Path) -> dict[str, int]:
    if not source_path.exists():
        raise FileNotFoundError(f"Build 1 database not found: {source_path}")

    init_db()
    source = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True)
    source.row_factory = sqlite3.Row
    db = SessionLocal()
    counts = {"users": 0, "people": 0, "locations": 0, "vehicles": 0, "journeys": 0, "assignments": 0, "alerts": 0, "events": 0}
    try:
        source_users = {row["id"]: row for row in _rows(source, "users")}
        users: dict[int, User] = {}
        for row in source_users.values():
            before = db.query(User).filter(User.email == str(row["email"]).lower()).first()
            users[row["id"]] = _user(db, row)
            counts["users"] += int(before is None)

        source_vehicles = {row["id"]: row for row in _rows(source, "vehicles")}
        vehicles: dict[int, Vehicle] = {}
        for row in source_vehicles.values():
            identifier = f"B1-{row['vehicle_number']}"
            item = db.query(Vehicle).filter(Vehicle.identifier == identifier).first()
            if not item:
                item = Vehicle(
                    identifier=identifier,
                    name=str(row["vehicle_number"]),
                    type=row["vehicle_type"] or "van",
                    status=row["status"] or "idle",
                )
                db.add(item)
                db.flush()
                counts["vehicles"] += 1
            vehicles[row["id"]] = item

        people: dict[int, Person] = {}
        customers: dict[int, Customer] = {}
        for row in _rows(source, "customers"):
            identifier = f"B1-C-{row['id']}"
            item = db.query(Person).filter(Person.identifier == identifier).first()
            location_code = f"B1-CUSTOMER-{row['id']}"
            location_was_present = db.query(Location).filter(Location.code == location_code).first() is not None
            location = _location(
                db,
                location_code,
                row["name"],
                float(row["latitude"]),
                float(row["longitude"]),
                "customer",
            )
            if not item:
                item = Person(
                    identifier=identifier,
                    name=row["name"],
                    status="tracked" if (row["status"] or "active") == "active" else "inactive",
                    current_location_id=location.id,
                )
                db.add(item)
                db.flush()
                counts["people"] += 1
            people[row["id"]] = item
            customer = db.query(Customer).filter(Customer.code == f"B1-{row['customer_code'] or row['id']}").first()
            if not customer:
                customer = Customer(
                    code=f"B1-{row['customer_code'] or row['id']}",
                    name=row["name"],
                    contact_name=row["contact_person"],
                    phone=row["phone"],
                    email=row["email"],
                    address=row["address"],
                    latitude=float(row["latitude"]),
                    longitude=float(row["longitude"]),
                    service_notes=row["notes"],
                    status=row["status"] or "active",
                )
                db.add(customer)
                db.flush()
            customers[row["id"]] = customer
            counts["locations"] += int(not location_was_present)

        source_routes = _rows(source, "routes")
        route_rows = {row["id"]: row for row in source_routes}
        active_trip_routes = {row["route_id"] for row in _rows(source, "trips") if row["status"] == "active"}
        journeys: dict[int, Journey] = {}
        for row in source_routes:
            identifier = f"B1-R-{row['id']}"
            item = db.query(Journey).filter(Journey.identifier == identifier).first()
            vehicle = vehicles.get(row["assigned_vehicle_id"])
            if vehicle is None:
                continue
            origin = _location(db, f"B1-ROUTE-{row['id']}-ORIGIN", row["start_address"] or row["name"], float(row["start_lat"] or 0), float(row["start_lng"] or 0), "depot")
            destination = _location(db, f"B1-ROUTE-{row['id']}-DESTINATION", row["end_address"] or row["name"], float(row["end_lat"] or row["start_lat"] or 0), float(row["end_lng"] or row["start_lng"] or 0), "destination")
            if not item:
                item = Journey(
                    identifier=identifier,
                    vehicle_id=vehicle.id,
                    origin_location_id=origin.id,
                    destination_location_id=destination.id,
                    status="active" if row["id"] in active_trip_routes else "planned",
                )
                db.add(item)
                db.flush()
                counts["journeys"] += 1
            journeys[row["id"]] = item

        # Preserve Build 1 driver identities as RouteOS people so their
        # imported accounts can use the authenticated /driver/me contract.
        for row in source_users.values():
            if row["role"] != "driver":
                continue
            user = users[row["id"]]
            identifier = f"B1-DRIVER-{row['id']}"
            person = db.query(Person).filter(Person.identifier == identifier).first()
            if not person:
                person = Person(identifier=identifier, name=row["name"], status="driver")
                db.add(person)
                db.flush()
                counts["people"] += 1
            user.person_id = person.id
            assigned_route = next((route for route in source_routes if route["assigned_driver_id"] == row["id"]), None)
            if assigned_route:
                journey = journeys.get(assigned_route["id"])
                vehicle = vehicles.get(assigned_route["assigned_vehicle_id"])
                if journey and vehicle:
                    person.current_journey_id = journey.id
                    person.current_vehicle_id = vehicle.id
                    person.status = "travelling" if journey.status == "active" else "driver"

        for row in _rows(source, "route_stops"):
            journey = journeys.get(row["route_id"])
            person = people.get(row["customer_id"])
            if not journey or not person:
                continue
            vehicle = vehicles.get(route_rows[row["route_id"]]["assigned_vehicle_id"])
            if not vehicle:
                continue
            assignment = db.query(Assignment).filter(Assignment.person_id == person.id, Assignment.journey_id == journey.id).first()
            if not assignment:
                db.add(Assignment(person_id=person.id, journey_id=journey.id, vehicle_id=vehicle.id, status="active"))
                counts["assignments"] += 1
            person.current_journey_id = journey.id
            person.current_vehicle_id = vehicle.id
            person.status = "travelling" if journey.status == "active" else person.status

        # Translate the delivery concepts into first-class product records as
        # well as the activity-centric Journey records above. This keeps the
        # imported Build 1 data visible to the new route/trip UI.
        product_routes: dict[int, Route] = {}
        for row in source_routes:
            vehicle = vehicles.get(row["assigned_vehicle_id"])
            driver = users.get(row["assigned_driver_id"]) if row["assigned_driver_id"] else None
            item = db.query(Route).filter(Route.code == f"B1-R-{row['id']}").first()
            if not item:
                item = Route(
                    code=f"B1-R-{row['id']}",
                    name=row["name"],
                    description=row["area"] or row["working_days"],
                    status=row["status"] or "active",
                    assigned_driver_id=driver.id if driver else None,
                    assigned_vehicle_id=vehicle.id if vehicle else None,
                    created_by_id=operator.id if (operator := users.get(next((key for key, value in source_users.items() if value["role"] == "admin"), None))) else None,
                    version=row["version"] or 1,
                )
                db.add(item)
                db.flush()
            product_routes[row["id"]] = item
        for row in _rows(source, "route_stops"):
            route = product_routes.get(row["route_id"])
            customer = customers.get(row["customer_id"])
            if not route or not customer:
                continue
            stop = db.query(RouteStop).filter(RouteStop.route_id == route.id, RouteStop.sequence == row["sequence"]).first()
            if not stop:
                db.add(RouteStop(route_id=route.id, customer_id=customer.id, sequence=row["sequence"], planned_arrival_time=row["planned_arrival_time"], service_duration_mins=row["service_duration_mins"] or 10, notes=row["notes"], status=row["status"] or "active"))
        db.flush()
        for row in _rows(source, "trips"):
            route = product_routes.get(row["route_id"])
            driver = users.get(row["driver_id"]) if row["driver_id"] else None
            vehicle = vehicles.get(row["vehicle_id"]) if row["vehicle_id"] else None
            if not route or not driver:
                continue
            trip = db.query(Trip).filter(Trip.code == f"B1-T-{row['id']}").first()
            if not trip:
                trip = Trip(code=f"B1-T-{row['id']}", route_id=route.id, driver_id=driver.id, vehicle_id=vehicle.id if vehicle else None, trip_date=_parse_datetime(row["date"]) or utcnow(), start_time=_parse_datetime(row["start_time"]), end_time=_parse_datetime(row["end_time"]), total_distance_km=row["total_distance_km"] or 0, status=row["status"] or "planned")
                db.add(trip)
                db.flush()
                for stop in db.query(RouteStop).filter(RouteStop.route_id == route.id).order_by(RouteStop.sequence):
                    db.add(TripStop(trip_id=trip.id, route_stop_id=stop.id, customer_id=stop.customer_id, sequence=stop.sequence, status="completed" if stop.sequence <= (row["completed_stops"] or 0) else "pending"))
        for row in _rows(source, "route_changes"):
            route = product_routes.get(row["route_id"])
            if not route:
                continue
            requested = users.get(row["requested_by_id"])
            if not requested:
                continue
            change = db.query(RouteChange).filter(RouteChange.route_id == route.id, RouteChange.customer_id == (customers.get(row["customer_id"]).id if customers.get(row["customer_id"]) else None), RouteChange.reason == "Imported from Build 1").first()
            if not change:
                db.add(RouteChange(route_id=route.id, customer_id=customers.get(row["customer_id"]).id if customers.get(row["customer_id"]) else None, change_type="add_stop", recommended_sequence=row["recommended_sequence"], additional_distance_km=row["additional_distance_km"] or 0, additional_time_mins=row["additional_time_mins"] or 0, reason="Imported from Build 1", status=row["status"] or "pending", requested_by_id=requested.id, approved_by_id=users.get(row["approved_by_id"]).id if users.get(row["approved_by_id"]) else None, decided_at=_parse_datetime(row["updated_at"])))

        for row in _rows(source, "route_changes"):
            journey = journeys.get(row["route_id"])
            if not journey or row["status"] != "pending":
                continue
            alert_key = f"BUILD1_ROUTE_CHANGE_{row['id']}"
            existing = db.query(Alert).filter(Alert.alert_type == alert_key).first()
            if not existing:
                db.add(Alert(
                    severity="warning",
                    alert_type=alert_key,
                    entity_type="journey",
                    entity_id=journey.id,
                    message=f"Build 1 route change awaiting review for {journey.identifier}",
                    payload={"source_route_change_id": row["id"], "recommended_sequence": row["recommended_sequence"]},
                ))
                counts["alerts"] += 1

        for row in _rows(source, "trips"):
            journey = journeys.get(row["route_id"])
            if not journey:
                continue
            event_key = f"BUILD1_TRIP_{row['id']}"
            if not db.query(Event).filter(Event.event_type == event_key).first():
                db.add(Event(
                    event_type=event_key,
                    entity_type="journey",
                    entity_id=journey.id,
                    timestamp=_parse_datetime(row["start_time"]) or utcnow(),
                    source="build1_import",
                    payload={"source_trip_id": row["id"], "status": row["status"], "completed_stops": row["completed_stops"], "total_stops": row["total_stops"]},
                ))
                counts["events"] += 1

        db.commit()
        return counts
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
        source.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()
    print(f"Importing Build 1 data from: {args.source}")
    print(import_build1(args.source))


if __name__ == "__main__":
    main()
