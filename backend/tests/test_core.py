from fastapi.testclient import TestClient
from auth import hash_password, verify_password
from database import Base, SessionLocal
from main import app
from models import User

def test_password_hashing():
    hashed = hash_password("correct-horse-battery")
    assert hashed != "correct-horse-battery"
    assert verify_password("correct-horse-battery", hashed)
    assert not verify_password("wrong-password", hashed)

def test_schema_contains_operational_entities():
    expected = {"people", "vehicles", "locations", "journeys", "assignments", "events", "alerts", "users"}
    assert expected.issubset(set(Base.metadata.tables))

def test_health_endpoint():
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_system_network_endpoint_exposes_client_presets_without_assuming_lan():
    with TestClient(app) as client:
        login = client.post("/auth/login", json={"email": "operator@routeos.local", "password": "operator123"}).json()
        response = client.get("/system/network", headers={"Authorization": f"Bearer {login['access_token']}"})
    payload = response.json()
    assert response.status_code == 200
    assert payload["bind_host"] == "0.0.0.0"
    assert payload["client_presets"]["android_emulator"] == "http://10.0.2.2:8000"
    assert all(url.startswith("http://") for url in payload["lan_urls"])

def test_authenticated_drivers_receive_only_their_persistent_assignment():
    with TestClient(app) as client:
        driver_a = client.post("/auth/login", json={"email": "driver1@routeos.local", "password": "driver123"}).json()
        driver_b = client.post("/auth/login", json={"email": "driver2@routeos.local", "password": "driver123"}).json()
        state_a = client.get("/driver/me", headers={"Authorization": f"Bearer {driver_a['access_token']}"})
        state_b = client.get("/driver/me", headers={"Authorization": f"Bearer {driver_b['access_token']}"})
        assert state_a.status_code == state_b.status_code == 200
        assert state_a.json()["journey"]["identifier"] == "J-101"
        assert state_a.json()["vehicle"]["identifier"] == "VEH-01"
        assert state_b.json()["journey"]["identifier"] == "J-102"
        assert state_b.json()["vehicle"]["identifier"] == "VEH-02"
        assert state_a.json()["journey"]["identifier"] != state_b.json()["journey"]["identifier"]

def test_driver_state_requires_driver_role_and_commands_validate_state():
    with TestClient(app) as client:
        operator = client.post("/auth/login", json={"email": "operator@routeos.local", "password": "operator123"}).json()
        driver = client.post("/auth/login", json={"email": "driver1@routeos.local", "password": "driver123"}).json()
        assert client.get("/driver/me", headers={"Authorization": f"Bearer {operator['access_token']}"}).status_code == 403
        forbidden = client.post("/commands", headers={"Authorization": f"Bearer {driver['access_token']}"}, json={"command": "STOP_JOURNEY", "payload": {"journey_id": 2}})
        assert forbidden.status_code == 403
        invalid_transition = client.post("/commands", headers={"Authorization": f"Bearer {driver['access_token']}"}, json={"command": "START_JOURNEY", "payload": {"journey_id": 1}})
        assert invalid_transition.status_code == 409

def test_driver_without_assignment_gets_an_empty_state():
    email = "unassigned-driver@routeos.local"
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            db.add(User(email=email, password_hash=hash_password("driver123"), role="driver"))
            db.commit()
    with TestClient(app) as client:
        login = client.post("/auth/login", json={"email": email, "password": "driver123"}).json()
        response = client.get("/driver/me", headers={"Authorization": f"Bearer {login['access_token']}"})
    assert response.status_code == 200
    assert response.json()["driver"] is None
    assert response.json()["journey"] is None
    assert response.json()["operational_status"] == "unassigned"

def test_driver_location_updates_are_validated_and_vehicle_scoped():
    with TestClient(app) as client:
        driver = client.post("/auth/login", json={"email": "driver1@routeos.local", "password": "driver123"}).json()
        headers = {"Authorization": f"Bearer {driver['access_token']}"}
        invalid = client.post("/vehicles/1/location", headers=headers, json={"latitude": 91, "longitude": 75})
        wrong_vehicle = client.post("/vehicles/2/location", headers=headers, json={"latitude": 11.2, "longitude": 75.8})
    assert invalid.status_code == 422
    assert wrong_vehicle.status_code == 403

def test_operator_can_assign_vehicle_and_set_destination():
    with TestClient(app) as client:
        operator = client.post("/auth/login", json={"email": "operator@routeos.local", "password": "operator123"}).json()
        headers = {"Authorization": f"Bearer {operator['access_token']}"}
        assigned = client.post("/commands", headers=headers, json={"command": "ASSIGN_VEHICLE", "payload": {"journey_id": 3, "vehicle_id": 4}})
        assert assigned.status_code == 200
        destination = client.post("/commands", headers=headers, json={"command": "SET_DESTINATION", "payload": {"journey_id": 3, "location_id": 5}})
        assert destination.status_code == 200


def test_driver_location_near_destination_marks_journey_arrived():
    with TestClient(app) as client:
        driver = client.post("/auth/login", json={"email": "driver1@routeos.local", "password": "driver123"}).json()
        headers = {"Authorization": f"Bearer {driver['access_token']}"}
        # J-101 destination is KOCHI in seeded data.
        response = client.post("/vehicles/1/location", headers=headers, json={"latitude": 9.9312, "longitude": 76.2673})
        assert response.status_code == 200
        state = client.get("/driver/me", headers=headers).json()
        assert state["journey"]["status"] == "arrived"
