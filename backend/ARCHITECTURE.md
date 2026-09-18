# Backend code guide

`main.py` assembles the server. It should remain a thin composition layer:
startup, middleware, health endpoints, and router registration.

Business responsibilities are separated as follows:

- `api.py`: activity-centric operations (`people`, `vehicles`, `locations`,
  `journeys`, alerts, events, commands, and system state).
- `product_api.py`: delivery operations (`customers`, `routes`, `trips`, route
  changes, proof of delivery, and analytics).
- `models.py`: persistence shape only.
- `schemas.py`: input validation only.
- `events.py`, `state.py`, and `automation.py`: the event/state/rules pipeline.
- `auth.py`: authentication and role checks used by both routers.
- `tui/`: terminal presentation; it calls the API and does not own database
  business logic.

For a new feature, follow this order:

1. Add or update the SQLAlchemy model and migration if storage changes.
2. Add a Pydantic schema for request validation.
3. Implement the endpoint in the appropriate router.
4. Publish an event when the operation changes state.
5. Add or update backend tests.
6. Update the Flutter model/service and then the screen.
