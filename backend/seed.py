"""
Seed script for Route App demo data.
Uses real Kozhikode, Kerala locations.
Run: python seed.py
"""
import os
import json
from datetime import datetime, timezone, date, timedelta
import random
from database import SessionLocal, engine
import models
from auth import get_password_hash
from config import settings

if settings.is_production:
    raise RuntimeError("Do not run seed.py in production!")

models.Base.metadata.create_all(bind=engine)

KOZHIKODE_CUSTOMERS = [
    # Route 1 — Mavoor Road Area (North)
    {"name": "SM Traders", "address": "Mavoor Road, Kozhikode", "lat": 11.2731, "lng": 75.7904, "phone": "9876501001", "type": "wholesale", "notes": "Call before arrival. Large gate on left side."},
    {"name": "Royal Provisions", "address": "Puthiyara, Kozhikode", "lat": 11.2764, "lng": 75.7956, "phone": "9876501002", "type": "retail", "notes": "Shop opens at 8:30 AM"},
    {"name": "Kerala Stores", "address": "Chevayur, Kozhikode", "lat": 11.2812, "lng": 75.8012, "phone": "9876501003", "type": "retail", "notes": "Prefer morning delivery"},
    {"name": "Malabar Distributors", "address": "Feroke, Kozhikode", "lat": 11.2680, "lng": 75.8156, "phone": "9876501004", "type": "wholesale", "notes": "Warehouse at back, use side entrance"},
    {"name": "Star Bakery", "address": "Kottakkal Road, Kozhikode", "lat": 11.2695, "lng": 75.7923, "phone": "9876501005", "type": "hotel", "notes": "Daily order 50 loaves"},
    {"name": "Green Valley Mart", "address": "Nadakkavu, Kozhikode", "lat": 11.2749, "lng": 75.7845, "phone": "9876501006", "type": "retail", "notes": "Park at main road"},
    {"name": "City Provisions", "address": "Thondayad, Kozhikode", "lat": 11.2802, "lng": 75.7891, "phone": "9876501007", "type": "retail", "notes": ""},
    {"name": "Sana General Stores", "address": "Palayam, Kozhikode", "lat": 11.2623, "lng": 75.7813, "phone": "9876501008", "type": "retail", "notes": "10 AM to 12 PM preferred"},
    {"name": "Hilite Mall Supplier", "address": "Hilite City, Kozhikode", "lat": 11.2741, "lng": 75.8023, "phone": "9876501009", "type": "wholesale", "notes": "Loading dock B"},

    # Route 2 — SM Street / Beach Area (West)
    {"name": "Haridas & Sons", "address": "SM Street, Kozhikode", "lat": 11.2510, "lng": 75.7716, "phone": "9876502001", "type": "wholesale", "notes": "Oldest customer. Priority delivery."},
    {"name": "Sarovaram Hotel", "address": "Beach Road, Kozhikode", "lat": 11.2486, "lng": 75.7672, "phone": "9876502002", "type": "hotel", "notes": "Back entrance. Delivery to kitchen."},
    {"name": "Kozhikode Bakes", "address": "Mananchira, Kozhikode", "lat": 11.2534, "lng": 75.7741, "phone": "9876502003", "type": "retail", "notes": ""},
    {"name": "Fortune Mart", "address": "Eranjipalam, Kozhikode", "lat": 11.2565, "lng": 75.7785, "phone": "9876502004", "type": "retail", "notes": "Ask for Manager Suresh"},
    {"name": "Cannanore Spices", "address": "Silk Street, Kozhikode", "lat": 11.2501, "lng": 75.7699, "phone": "9876502005", "type": "wholesale", "notes": ""},
    {"name": "Beach View Provisions", "address": "Kallai Road, Kozhikode", "lat": 11.2478, "lng": 75.7651, "phone": "9876502006", "type": "retail", "notes": ""},
    {"name": "Malabar Palace Stores", "address": "Convent Road, Kozhikode", "lat": 11.2522, "lng": 75.7728, "phone": "9876502007", "type": "retail", "notes": ""},

    # Route 3 — Calicut University Area (East)
    {"name": "University Canteen Supply", "address": "Tenhipalam, Malappuram", "lat": 11.1760, "lng": 75.9419, "phone": "9876503001", "type": "wholesale", "notes": "Large order every Monday"},
    {"name": "Agroha Supermarket", "address": "Perinthalmanna Rd, Malappuram", "lat": 11.1812, "lng": 75.9342, "phone": "9876503002", "type": "retail", "notes": ""},
    {"name": "Kondotty Traders", "address": "Kondotty, Malappuram", "lat": 11.1698, "lng": 75.9478, "phone": "9876503003", "type": "wholesale", "notes": ""},
    {"name": "East Kerala Provisions", "address": "Tirur, Malappuram", "lat": 11.1523, "lng": 75.9211, "phone": "9876503004", "type": "retail", "notes": ""},
    {"name": "Kalpetta Distributors", "address": "Karuvarakkundu, Malappuram", "lat": 11.1645, "lng": 75.9388, "phone": "9876503005", "type": "wholesale", "notes": ""},

    # Route 4 — Koyilandy Area (South)
    {"name": "Koyilandy Super Stores", "address": "Koyilandy, Kozhikode", "lat": 11.4020, "lng": 75.7043, "phone": "9876504001", "type": "retail", "notes": ""},
    {"name": "Vadakara Fresh Mart", "address": "Vadakara, Kozhikode", "lat": 11.5986, "lng": 75.5901, "phone": "9876504002", "type": "retail", "notes": "Far stop — start early"},
    {"name": "Quilandy Fish Market Supply", "address": "Koyilandy Market", "lat": 11.4068, "lng": 75.7021, "phone": "9876504003", "type": "wholesale", "notes": "Early morning only — before 8 AM"},
    {"name": "Perambra Traders", "address": "Perambra, Kozhikode", "lat": 11.3921, "lng": 75.7289, "phone": "9876504004", "type": "retail", "notes": ""},
    {"name": "North Kerala Wholesale", "address": "Koyilandy Rd, Kozhikode", "lat": 11.3845, "lng": 75.7312, "phone": "9876504005", "type": "wholesale", "notes": ""},

    # Route 5 — Medical / Pharmacy Route
    {"name": "Malabar Medical Hall", "address": "Medical College Road, Kozhikode", "lat": 11.2589, "lng": 75.8143, "phone": "9876505001", "type": "pharmacy", "notes": "Cold chain required"},
    {"name": "Govt. Medical College Supply", "address": "KMCT Road, Kozhikode", "lat": 11.2601, "lng": 75.8201, "phone": "9876505002", "type": "pharmacy", "notes": "Security gate — call ahead"},
    {"name": "Apollo Pharmacy Kozhikode", "address": "Indira Gandhi Road, Kozhikode", "lat": 11.2634, "lng": 75.8089, "phone": "9876505003", "type": "pharmacy", "notes": ""},
    {"name": "Health Plus Medical Store", "address": "Kallai, Kozhikode", "lat": 11.2579, "lng": 75.8034, "phone": "9876505004", "type": "pharmacy", "notes": ""},
    {"name": "Medicare Distributors", "address": "West Hill, Kozhikode", "lat": 11.2671, "lng": 75.8176, "phone": "9876505005", "type": "pharmacy", "notes": ""},
    {"name": "Nandhi Medical Agencies", "address": "Arayidathupalam, Kozhikode", "lat": 11.2648, "lng": 75.8112, "phone": "9876505006", "type": "pharmacy", "notes": ""},

    # Extra customers (unassigned / for new insertion demo)
    {"name": "Rahul Provisions", "address": "East Hill, Kozhikode", "lat": 11.2715, "lng": 75.8034, "phone": "9876506001", "type": "retail", "notes": "New customer"},
    {"name": "Zahra Supermarket", "address": "Palazhi, Kozhikode", "lat": 11.2780, "lng": 75.7921, "phone": "9876506002", "type": "retail", "notes": ""},
    {"name": "Calicut Heritage Store", "address": "Mittaimala Road, Kozhikode", "lat": 11.2538, "lng": 75.7756, "phone": "9876506003", "type": "wholesale", "notes": ""},
    {"name": "Fathima General Stores", "address": "Cherootty Road, Kozhikode", "lat": 11.2503, "lng": 75.7742, "phone": "9876506004", "type": "retail", "notes": ""},
    {"name": "New Malabar Traders", "address": "Palarivattom Junction, Kozhikode", "lat": 11.2662, "lng": 75.7899, "phone": "9876506005", "type": "wholesale", "notes": ""},
]

EMPLOYEES = [
    {"name": "Arun Kumar", "email": "arun@routeapp.com", "password": "driver123", "role": "driver", "phone": "9876500101"},
    {"name": "Rahul Menon", "email": "rahul@routeapp.com", "password": "driver123", "role": "driver", "phone": "9876500102"},
    {"name": "Suresh Nair", "email": "suresh@routeapp.com", "password": "driver123", "role": "driver", "phone": "9876500103"},
    {"name": "Manoj Pillai", "email": "manoj@routeapp.com", "password": "driver123", "role": "driver", "phone": "9876500104"},
    {"name": "Anvar Sadath", "email": "anvar@routeapp.com", "password": "driver123", "role": "driver", "phone": "9876500105"},
    {"name": "Deepa Krishnan", "email": "deepa@routeapp.com", "password": "supervisor123", "role": "supervisor", "phone": "9876500201"},
]

VEHICLES = [
    {"number": "KL 11 AB 1234", "reg": "KL11AB1234", "type": "van", "capacity": 800.0},
    {"number": "KL 11 CD 5678", "reg": "KL11CD5678", "type": "van", "capacity": 800.0},
    {"number": "KL 11 EF 9012", "reg": "KL11EF9012", "type": "truck", "capacity": 2000.0},
    {"number": "KL 11 GH 3456", "reg": "KL11GH3456", "type": "car", "capacity": 300.0},
    {"number": "KL 11 IJ 7890", "reg": "KL11IJ7890", "type": "bike", "capacity": 50.0},
]

# Warehouse location — Kozhikode main depot (near Mavoor Rd)
DEPOT_LAT = 11.2588
DEPOT_LNG = 75.7804
DEPOT_ADDRESS = "Main Warehouse, Mavoor Road, Kozhikode"

ROUTES_DEFINITION = [
    {
        "name": "Route 01 — Mavoor Road North",
        "area": "Mavoor Road, North Kozhikode",
        "days": ["Monday", "Thursday"],
        "driver_idx": 0,
        "vehicle_idx": 0,
        "customer_indices": [0, 1, 2, 3, 4, 5, 6, 7, 8],
    },
    {
        "name": "Route 02 — SM Street & Beach",
        "area": "SM Street, Beach Road, Mananchira",
        "days": ["Tuesday", "Friday"],
        "driver_idx": 1,
        "vehicle_idx": 1,
        "customer_indices": [9, 10, 11, 12, 13, 14, 15],
    },
    {
        "name": "Route 03 — University & East",
        "area": "Tenhipalam, Malappuram Belt",
        "days": ["Monday", "Wednesday"],
        "driver_idx": 2,
        "vehicle_idx": 2,
        "customer_indices": [16, 17, 18, 19, 20],
    },
    {
        "name": "Route 04 — Koyilandy South",
        "area": "Koyilandy, Vadakara",
        "days": ["Wednesday", "Saturday"],
        "driver_idx": 3,
        "vehicle_idx": 0,
        "customer_indices": [21, 22, 23, 24, 25],
    },
    {
        "name": "Route 05 — Medical & Pharma",
        "area": "Medical College Road, West Hill",
        "days": ["Monday", "Tuesday", "Thursday", "Friday"],
        "driver_idx": 4,
        "vehicle_idx": 3,
        "customer_indices": [26, 27, 28, 29, 30, 31],
    },
]


def seed():
    db = SessionLocal()
    try:
        # Clear existing
        db.query(models.TripStop).delete()
        db.query(models.Trip).delete()
        db.query(models.RouteChange).delete()
        db.query(models.RouteVersion).delete()
        db.query(models.RouteStop).delete()
        db.query(models.Route).delete()
        db.query(models.Vehicle).delete()
        db.query(models.Customer).delete()
        db.query(models.User).delete()
        db.commit()

        # Admin user
        admin = models.User(
            name="Admin Manager",
            email="admin@routeapp.com",
            password_hash=get_password_hash("admin123"),
            role="admin",
            phone="9876500001",
        )
        db.add(admin)
        db.flush()

        # Employees
        users = [admin]
        for e in EMPLOYEES:
            user = models.User(
                name=e["name"],
                email=e["email"],
                password_hash=get_password_hash(e["password"]),
                role=e["role"],
                phone=e["phone"],
            )
            db.add(user)
            db.flush()
            users.append(user)

        # Vehicles
        vehicles = []
        for i, v in enumerate(VEHICLES):
            driver_user = users[i + 1] if i < len(EMPLOYEES) else None
            vehicle = models.Vehicle(
                vehicle_number=v["number"],
                registration=v["reg"],
                vehicle_type=v["type"],
                capacity_kg=v["capacity"],
                assigned_driver_id=driver_user.id if driver_user and driver_user.role == "driver" else None,
            )
            db.add(vehicle)
            db.flush()
            vehicles.append(vehicle)

        # Customers
        customers = []
        for i, c in enumerate(KOZHIKODE_CUSTOMERS):
            cust = models.Customer(
                name=c["name"],
                address=c["address"],
                latitude=c["lat"],
                longitude=c["lng"],
                phone=c["phone"],
                customer_type=c["type"],
                notes=c.get("notes", ""),
                contact_person="Manager",
                service_duration_mins=random.choice([10, 15, 20, 25]),
                preferred_visit_time=random.choice(["09:00-11:00", "10:00-12:00", "14:00-17:00", None]),
                visit_days=json.dumps(["Monday", "Thursday"]),
            )
            db.add(cust)
            db.flush()
            customers.append(cust)

        # Routes
        routes = []
        for i, rd in enumerate(ROUTES_DEFINITION):
            driver_user = users[rd["driver_idx"] + 1]  # +1 because index 0 is admin
            vehicle = vehicles[rd["vehicle_idx"]]

            route = models.Route(
                name=rd["name"],
                area=rd["area"],
                working_days=json.dumps(rd["days"]),
                start_lat=DEPOT_LAT,
                start_lng=DEPOT_LNG,
                start_address=DEPOT_ADDRESS,
                end_lat=DEPOT_LAT,
                end_lng=DEPOT_LNG,
                end_address=DEPOT_ADDRESS,
                assigned_driver_id=driver_user.id,
                assigned_vehicle_id=vehicle.id,
                version=1,
            )
            db.add(route)
            db.flush()
            routes.append(route)

            # Version 1
            version = models.RouteVersion(
                route_id=route.id,
                version=1,
                snapshot="[]",
                change_summary="Route created",
                changed_by_id=admin.id,
            )
            db.add(version)

            # Add stops
            for seq, cust_idx in enumerate(rd["customer_indices"], start=1):
                cust = customers[cust_idx]
                stop = models.RouteStop(
                    route_id=route.id,
                    customer_id=cust.id,
                    sequence=seq,
                    service_duration_mins=cust.service_duration_mins,
                    notes=cust.notes,
                )
                db.add(stop)

            db.flush()

        db.commit()

        # Add a sample pending route change
        change = models.RouteChange(
            route_id=routes[0].id,
            customer_id=customers[32].id,  # Rahul Provisions (unassigned)
            recommended_sequence=5,
            additional_distance_km=1.2,
            additional_time_mins=2.9,
            status="pending",
            requested_by_id=users[1].id,  # Arun
        )
        db.add(change)

        # Add a few demo trips for today
        today = datetime.now(timezone.utc).date()
        for i, (route, rd) in enumerate(zip(routes[:3], ROUTES_DEFINITION[:3])):
            driver_user = users[rd["driver_idx"] + 1]
            total_stops = len(rd["customer_indices"])
            completed = random.randint(total_stops // 2, total_stops - 1)

            trip = models.Trip(
                route_id=route.id,
                driver_id=driver_user.id,
                vehicle_id=vehicles[rd["vehicle_idx"]].id,
                date=today,
                start_time=datetime.now(timezone.utc) - timedelta(hours=3),
                total_stops=total_stops,
                completed_stops=completed,
                total_distance_km=round(random.uniform(20, 60), 1),
                status="active" if i < 2 else "completed",
            )
            db.add(trip)
            db.flush()

            cust_list = [customers[idx] for idx in rd["customer_indices"]]
            for seq, cust in enumerate(cust_list, start=1):
                route_stop = db.query(models.RouteStop).filter(
                    models.RouteStop.route_id == route.id,
                    models.RouteStop.customer_id == cust.id,
                ).first()
                if not route_stop:
                    continue
                ts_status = "pending"
                if seq <= completed:
                    ts_status = "completed"
                ts = models.TripStop(
                    trip_id=trip.id,
                    route_stop_id=route_stop.id,
                    customer_id=cust.id,
                    sequence=seq,
                    status=ts_status,
                    arrival_time=datetime.now(timezone.utc) - timedelta(minutes=(total_stops - seq) * 15) if seq <= completed else None,
                )
                db.add(ts)

        db.commit()
        print("Seed complete!")
        print("   Admin:    admin@routeapp.com / admin123")
        print("   Driver 1: arun@routeapp.com / driver123")
        print("   Driver 2: rahul@routeapp.com / driver123")
        print(f"   {len(KOZHIKODE_CUSTOMERS)} customers seeded across {len(ROUTES_DEFINITION)} routes")
        print("   Location: Kozhikode, Kerala")

    except Exception as e:
        db.rollback()
        print(f"Seed failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
