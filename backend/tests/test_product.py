from fastapi.testclient import TestClient

from main import app


def _login(client: TestClient, email: str, password: str) -> dict[str, str]:
    response = client.post("/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def test_product_domains_are_seeded_and_scoped():
    with TestClient(app) as client:
        operator = _login(client, "operator@routeos.local", "operator123")
        customers = client.get("/customers", headers=operator)
        routes = client.get("/routes", headers=operator)
        trips = client.get("/trips", headers=operator)
        analytics = client.get("/analytics/dashboard", headers=operator)
        assert customers.status_code == routes.status_code == trips.status_code == analytics.status_code == 200
        assert len(customers.json()) >= 5
        assert routes.json()[0]["stops"]
        assert trips.json()[0]["status"] == "active"
        assert analytics.json()["total_routes"] >= 1

        driver = _login(client, "driver1@routeos.local", "driver123")
        driver_trips = client.get("/trips", headers=driver)
        assert driver_trips.status_code == 200
        assert all(item["driver_id"] == 3 for item in driver_trips.json())


def test_driver_cannot_complete_a_stop_without_receiver_information():
    with TestClient(app) as client:
        driver = _login(client, "driver1@routeos.local", "driver123")
        trips = client.get("/trips", headers=driver).json()
        trip = trips[0]
        stop = trip["trip_stops"][0]
        response = client.put(
            f"/trips/{trip['id']}/stops/{stop['id']}",
            headers=driver,
            json={"action": "complete"},
        )
        assert response.status_code == 422


def test_operator_can_create_customer_and_route_change_is_admin_decided():
    with TestClient(app) as client:
        operator = _login(client, "operator@routeos.local", "operator123")
        customer = client.post(
            "/customers",
            headers=operator,
            json={"code": "CUS-TEST", "name": "Test Customer", "phone": "555-0100"},
        )
        assert customer.status_code == 200
        route = client.get("/routes", headers=operator).json()[0]
        change = client.post(
            "/route-changes",
            headers=operator,
            json={"route_id": route["id"], "customer_id": customer.json()["id"], "change_type": "add_stop", "reason": "Test approval"},
        )
        assert change.status_code == 200
        admin = _login(client, "admin@routeos.local", "admin123")
        decision = client.put(f"/route-changes/{change.json()['id']}/approve", headers=admin)
        assert decision.status_code == 200
        assert decision.json()["status"] == "approved"
