from datetime import datetime, timedelta, timezone
from pathlib import Path
from sqlalchemy.orm import Session
from database import SessionLocal, init_db
from config import settings
from models import Alert, Assignment, Customer, Event, Journey, Location, Person, Route, RouteStop, Trip, TripStop, User, Vehicle, now
from auth import hash_password

def seed(db: Session):
    if db.query(User).first(): return False
    admin = User(email="admin@routeos.local", password_hash=hash_password("admin123"), role="admin")
    operator = User(email="operator@routeos.local", password_hash=hash_password("operator123"), role="operator")
    db.add_all([admin, operator]); db.flush()
    locations = [Location(code=code, name=name, type=kind, latitude=lat, longitude=lng) for code, name, kind, lat, lng in [
        ("GATE_A", "Main Gate", "gate", 11.2588, 75.7804), ("DEPOT", "Central Depot", "depot", 11.2700, 75.7750),
        ("KOCHI", "Kochi Hub", "city", 9.9312, 76.2673), ("MUNNAR", "Munnar Station", "city", 10.0889, 77.0595),
        ("KOTTAYAM", "Kottayam Hub", "city", 9.5916, 76.5222), ("WAREHOUSE", "Warehouse 01", "warehouse", 11.2450, 75.7900)]]
    db.add_all(locations); db.flush()
    vehicles = []
    for i in range(1, 9): vehicles.append(Vehicle(identifier=f"VEH-{i:02d}", name=f"RouteOS Vehicle {i:02d}", type="van" if i < 6 else "truck", status="idle", latitude=11.25 + i * .002, longitude=75.77 + i * .002, last_seen=now() - timedelta(minutes=i * 2)))
    db.add_all(vehicles); db.flush()
    people = [Person(identifier=f"P-{i:03d}", name=f"Operator Person {i:03d}", status="inside" if i % 5 else "outside") for i in range(1, 25)]
    people.extend([Person(identifier="DRIVER-01", name="RouteOS Driver 01", status="driver"), Person(identifier="DRIVER-02", name="RouteOS Driver 02", status="driver")])
    db.add_all(people); db.flush()
    journeys = [Journey(identifier="J-101", vehicle_id=vehicles[0].id, origin_location_id=locations[1].id, destination_location_id=locations[2].id, status="active", started_at=now() - timedelta(hours=1)), Journey(identifier="J-102", vehicle_id=vehicles[1].id, origin_location_id=locations[1].id, destination_location_id=locations[3].id, status="active", started_at=now() - timedelta(minutes=35)), Journey(identifier="J-103", vehicle_id=vehicles[2].id, origin_location_id=locations[0].id, destination_location_id=locations[4].id, status="planned")]
    db.add_all(journeys); db.flush()
    for journey, vehicle in zip(journeys[:2], vehicles[:2]): vehicle.current_journey_id = journey.id; vehicle.status = "moving"
    for person in people[:12]: person.current_vehicle_id = vehicles[0].id; person.current_journey_id = journeys[0].id; person.status = "travelling"
    for person in people[12:17]: person.current_vehicle_id = vehicles[1].id; person.current_journey_id = journeys[1].id; person.status = "travelling"
    people[-2].current_vehicle_id = vehicles[0].id; people[-2].current_journey_id = journeys[0].id; people[-2].status = "travelling"
    people[-1].current_vehicle_id = vehicles[1].id; people[-1].current_journey_id = journeys[1].id; people[-1].status = "travelling"
    assigned_people = people[:17] + people[-2:]
    db.add_all([
        Assignment(person_id=person.id, journey_id=person.current_journey_id, vehicle_id=person.current_vehicle_id, status="active")
        for person in assigned_people if person.current_journey_id and person.current_vehicle_id
    ])
    driver_one = User(email="driver1@routeos.local", password_hash=hash_password("driver123"), role="driver", person_id=people[-2].id)
    driver_two = User(email="driver2@routeos.local", password_hash=hash_password("driver123"), role="driver", person_id=people[-1].id)
    db.add_all([driver_one, driver_two])
    db.add_all([Event(event_type="SYSTEM_STARTED", entity_type="system", source="seed", payload={"demo": True}), Event(event_type="JOURNEY_STARTED", entity_type="journey", entity_id=journeys[0].id, source="seed", payload={}), Event(event_type="PERSON_ENTERED_VEHICLE", entity_type="person", entity_id=people[0].id, source="seed", payload={"vehicle_id": vehicles[0].id})])
    db.add_all([Alert(severity="warning", alert_type="GPS_STALE", entity_type="vehicle", entity_id=vehicles[6].id, message="VEH-07 has stale GPS data", payload={}), Alert(severity="critical", alert_type="UNASSIGNED_PERSON", entity_type="person", entity_id=people[20].id, message="P-021 is not assigned to an active journey", payload={}), Alert(severity="info", alert_type="SYSTEM_ERROR", entity_type="system", message="Previous test alert resolved", status="resolved", resolved_at=now(), resolved_by=admin.id, payload={})])
    db.commit(); return True

if __name__ == "__main__":
    if settings.is_production: raise SystemExit("Refusing to seed production")
    init_db()
    with SessionLocal() as db: print("Seeded demo data" if seed(db) else "Demo data already exists")


def seed_product_demo(db: Session) -> bool:
    """Add the delivery product demo layer without duplicating imported data."""
    existing_route = db.query(Route).first()
    if existing_route:
        if not db.query(Trip).filter(Trip.route_id == existing_route.id).first():
            driver = db.query(User).filter(User.role == "driver", User.status == "active").order_by(User.id).first()
            vehicle = db.get(Vehicle, existing_route.assigned_vehicle_id) if existing_route.assigned_vehicle_id else None
            if driver:
                trip = Trip(code=f"TRIP-DEMO-{existing_route.id:03d}", route_id=existing_route.id, driver_id=driver.id, vehicle_id=vehicle.id if vehicle else None, trip_date=now(), start_time=now(), status="active")
                db.add(trip)
                db.flush()
                for stop in db.query(RouteStop).filter(RouteStop.route_id == existing_route.id).order_by(RouteStop.sequence).all():
                    db.add(TripStop(trip_id=trip.id, route_stop_id=stop.id, customer_id=stop.customer_id, sequence=stop.sequence, notes=stop.notes))
                db.commit()
        return False
    operator = db.query(User).filter(User.role.in_(["admin", "operator"])).order_by(User.id).first()
    driver = db.query(User).filter(User.email == "arun@routeapp.com", User.role == "driver", User.status == "active").first()
    driver = driver or db.query(User).filter(User.role == "driver", User.status == "active").order_by(User.id).first()
    vehicle = db.query(Vehicle).order_by(Vehicle.id).first()
    if not operator or not driver:
        return False
    customers = []
    for index, (name, phone, lat, lng) in enumerate([
        ("Harbor Market", "+91 98470 11001", 11.2580, 75.7800),
        ("Malabar Pharmacy", "+91 98470 11002", 11.2620, 75.7830),
        ("Coastal Suites", "+91 98470 11003", 11.2690, 75.7740),
        ("Kozhikode Fresh", "+91 98470 11004", 11.2470, 75.7890),
        ("North Hub Cafe", "+91 98470 11005", 11.2750, 75.7680),
    ], start=1):
        item = Customer(code=f"CUS-{index:03d}", name=name, contact_name="RouteOS contact", phone=phone, address=f"Kozhikode delivery point {index}", latitude=lat, longitude=lng, service_notes="Call on arrival")
        db.add(item)
        customers.append(item)
    db.flush()
    route = Route(code="R-001", name="Kozhikode City Loop", description="Daily city delivery circuit", assigned_driver_id=driver.id, assigned_vehicle_id=vehicle.id if vehicle else None, created_by_id=operator.id)
    db.add(route)
    db.flush()
    for sequence, customer in enumerate(customers, start=1):
        db.add(RouteStop(route_id=route.id, customer_id=customer.id, sequence=sequence, planned_arrival_time=f"{8 + sequence}:30", service_duration_mins=12))
    db.commit()
    db.refresh(route)
    trip = Trip(code="TRIP-DEMO-001", route_id=route.id, driver_id=driver.id, vehicle_id=vehicle.id if vehicle else None, trip_date=now(), start_time=now(), status="active")
    db.add(trip)
    db.flush()
    for stop in db.query(RouteStop).filter(RouteStop.route_id == route.id).order_by(RouteStop.sequence).all():
        db.add(TripStop(trip_id=trip.id, route_stop_id=stop.id, customer_id=stop.customer_id, sequence=stop.sequence, notes=stop.notes))
    db.commit()
    return True
