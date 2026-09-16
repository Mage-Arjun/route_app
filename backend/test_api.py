import httpx

BASE = 'http://127.0.0.1:8000'
passed = 0
failed = 0

def test(name, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"[PASS] {name}" + (f" -- {detail}" if detail else ""))
    else:
        failed += 1
        print(f"[FAIL] {name}" + (f" -- {detail}" if detail else ""))

# Login as admin
r = httpx.post(f"{BASE}/auth/login", json={"email": "admin@routeapp.com", "password": "admin123"})
test("Admin login", r.status_code == 200, f"status={r.status_code}")
token = r.json()["access_token"]
h = {"Authorization": f"Bearer {token}"}

# Health
r = httpx.get(f"{BASE}/health")
test("Health check", r.status_code == 200)

# Users
r = httpx.get(f"{BASE}/users/", headers=h)
test("List users", r.status_code == 200 and len(r.json()) >= 6, f"{len(r.json())} users")

# Customers
r = httpx.get(f"{BASE}/customers/", headers=h)
test("List customers", r.status_code == 200 and len(r.json()) >= 30, f"{len(r.json())} customers")

# Customers pagination
r = httpx.get(f"{BASE}/customers/?limit=5", headers=h)
test("Customers pagination", r.status_code == 200 and len(r.json()) <= 5, f"limit=5 -> {len(r.json())}")

# Customers search
r = httpx.get(f"{BASE}/customers/?search=SM", headers=h)
test("Customer search", r.status_code == 200 and len(r.json()) >= 1, f"search=SM -> {len(r.json())}")

# Customers filter by type
r = httpx.get(f"{BASE}/customers/?customer_type=pharmacy", headers=h)
test("Customer type filter", r.status_code == 200, f"pharmacy -> {len(r.json())}")

# Vehicles
r = httpx.get(f"{BASE}/vehicles/", headers=h)
test("List vehicles", r.status_code == 200 and len(r.json()) >= 4, f"{len(r.json())} vehicles")

# Routes
r = httpx.get(f"{BASE}/routes/", headers=h)
test("List routes", r.status_code == 200 and len(r.json()) == 5, f"{len(r.json())} routes")

# Route detail
r = httpx.get(f"{BASE}/routes/1", headers=h)
route = r.json()
test("Route detail", r.status_code == 200 and len(route["stops"]) > 0, f"{route['name']} - {len(route['stops'])} stops")

# Route versions
r = httpx.get(f"{BASE}/routes/1/versions", headers=h)
test("Route versions", r.status_code == 200 and len(r.json()) >= 1, f"{len(r.json())} versions")

# Trips
r = httpx.get(f"{BASE}/trips/", headers=h)
test("List trips", r.status_code == 200, f"{len(r.json())} trips")

# Dashboard
r = httpx.get(f"{BASE}/analytics/dashboard", headers=h)
stats = r.json()
test("Dashboard stats", r.status_code == 200 and stats["total_routes"] > 0, f"{stats['total_routes']} routes, {stats['total_customers']} customers")

# Route analytics
r = httpx.get(f"{BASE}/analytics/routes/1", headers=h)
test("Route analytics", r.status_code == 200, r.json()["route_name"])

# Pending changes
r = httpx.get(f"{BASE}/routes/changes/pending", headers=h)
test("Pending changes", r.status_code == 200, f"{len(r.json())} pending")

# All changes
r = httpx.get(f"{BASE}/routes/changes/", headers=h)
test("All changes", r.status_code == 200, f"{len(r.json())} total")

# Self-update
r = httpx.put(f"{BASE}/users/me", headers=h, json={"phone": "1234567890"})
test("Self-update profile", r.status_code == 200)

# Driver login
r = httpx.post(f"{BASE}/auth/login", json={"email": "arun@routeapp.com", "password": "driver123"})
test("Driver login", r.status_code == 200)
dh = {"Authorization": f"Bearer {r.json()['access_token']}"}

# Driver sees own routes
r = httpx.get(f"{BASE}/routes/", headers=dh)
test("Driver routes", r.status_code == 200, f"{len(r.json())} routes")

# Driver sees own trips
r = httpx.get(f"{BASE}/trips/", headers=dh)
test("Driver trips", r.status_code == 200, f"{len(r.json())} trips")

# Driver blocked from creating customer
r = httpx.post(f"{BASE}/customers/", headers=dh, json={"name": "Test", "latitude": 11.25, "longitude": 75.78})
test("Driver blocked from create customer", r.status_code == 403)

# Driver blocked from creating vehicle
r = httpx.post(f"{BASE}/vehicles/", headers=dh, json={"vehicle_number": "TEST 0001"})
test("Driver blocked from create vehicle", r.status_code == 403)

# Start trip (admin can start on any route - use route 4 which has no active trips from seed)
r = httpx.post(f"{BASE}/trips/", headers=h, json={"route_id": 4})
test("Start trip (admin)", r.status_code == 200, f"trip_id={r.json()['id']}" if r.status_code == 200 else f"status={r.status_code}")

# Duplicate trip prevention (admin already has active trip on route 4 now)
r2 = httpx.post(f"{BASE}/trips/", headers=h, json={"route_id": 4})
test("Duplicate trip prevented", r2.status_code == 400, r2.json().get("detail", ""))

# Driver blocked from starting trip on unassigned route
r3 = httpx.post(f"{BASE}/trips/", headers=dh, json={"route_id": 2})
test("Driver blocked from unassigned route", r3.status_code == 403)

print()
print(f"=== {passed} PASSED, {failed} FAILED ===")
if failed > 0:
    exit(1)
