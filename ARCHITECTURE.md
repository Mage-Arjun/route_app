# RouteOS project map

This file is the quick reference for finding code. The application has two
independent runtimes:

- `backend/` is the FastAPI server, database, event engine, and terminal UI.
- `route_os/` is the Flutter mobile/web client.

## Flutter client

```text
route_os/lib/
├── main.dart                         App startup and authenticated home routing
├── config/
│   ├── api.dart                       Base URL, JWT storage, Dio client/interceptor
│   └── theme.dart                     Light/dark Material themes and shared palette
├── providers/
│   ├── auth_provider.dart             Login, logout, auto-login, current user
│   └── preferences_provider.dart      Theme, notification, and location preferences
├── services/
│   ├── api_service.dart               All HTTP calls; this is the API boundary
│   └── location_service.dart           GPS permissions, sampling, and location upload
├── models/                            Backend response models and JSON parsing only
├── screens/auth/                      Login and registration
├── screens/admin/                     Operator/admin workflows
│   ├── dashboard_screen.dart          KPIs and shortcuts
│   ├── route_*                        Route list, form, detail, and analytics
│   ├── customer_*                     Customer list and form
│   ├── vehicle_*                      Fleet list and form
│   ├── live_tracking_screen.dart      Vehicle tracking list
│   └── map_screen.dart                MapLibre operations map
├── screens/driver/                    Driver workflows
│   ├── driver_home_screen.dart        Assigned routes and active trips
│   ├── trip_screen.dart               Stops, POD, GPS path, and trip actions
│   └── driver_profile_screen.dart     Driver account view
└── screens/shared/                    Navigation and settings shared by roles
```

### Flutter change rules

1. Add or change an endpoint in `services/api_service.dart` first.
2. Change JSON fields in `models/`, not inside widgets.
3. Keep network/loading/error state in the screen that owns the request.
4. Put reusable application-wide styling in `config/theme.dart`; avoid new
   hardcoded page backgrounds.
5. Keep admin and driver screens role-specific. Shared navigation belongs in
   `screens/shared/`.

## Backend

```text
backend/
├── main.py                            FastAPI app, startup, CORS, routers
├── api.py                             Core operations API: people, vehicles, journeys
├── product_api.py                     Delivery API: customers, routes, trips, POD
├── schemas.py                         Pydantic request/response validation
├── models.py                          SQLAlchemy tables
├── database.py                        Engine, sessions, database initialization
├── auth.py                            JWT and role authorization dependencies
├── events.py                           Event persistence and WebSocket broadcast
├── state.py                            Operational state updates
├── automation.py                       Background rules/automation
├── commands.py                         Validated operator command execution
├── tui/                                Textual terminal operator console
├── migrations/                         Alembic migration history
├── tests/                              Backend tests
└── routeos.sh                          Portable launcher
```

The backend's two API modules are intentional: `api.py` contains the original
activity/occupancy operations, while `product_api.py` contains the delivery
workflow used by the Flutter client. Do not add business logic to a widget or
duplicate it in a second endpoint.

## Common workflows

| Task | Start here | Then inspect |
|---|---|---|
| Change login/session | `route_os/lib/providers/auth_provider.dart` | `services/api_service.dart`, `backend/auth.py` |
| Change a backend field | `backend/models.py` / `backend/schemas.py` | matching Flutter model |
| Change route UI | `screens/admin/route_list_screen.dart` | route form/detail and `ApiService` |
| Change driver delivery flow | `screens/driver/trip_screen.dart` | `product_api.py` trip/POD handlers |
| Change map behavior | `screens/admin/map_screen.dart` | `models/vehicle.dart`, `/vehicles` endpoint |
| Change theme | `config/theme.dart`, `preferences_provider.dart` | screen hardcoded colors |
| Add a database field | model + Alembic migration | seed data and tests |

## Route-planning workflow

Operators start in `route_os/lib/screens/admin/route_form_screen.dart`.
**Open route planner** opens `route_builder_screen.dart`, where a person can
search worldwide places, tap the map to add ordered waypoints, or record a
path using GPS. The planner returns a draft to the form; the form sends it as
`geometry` only when the operator presses Save.

The backend stores geometry as ordered `[longitude, latitude]` pairs (the
standard GeoJSON order). Flutter converts them to
`LatLng(latitude, longitude)` before drawing. Drivers see routes assigned to
them or still unassigned; claiming happens when they start a trip. Admins and
operators see the same saved line in route details.

`GET /geo/search` is the authenticated backend proxy for worldwide place
search. It uses OpenStreetMap Nominatim with a descriptive user-agent, so the
mobile app has one API origin and does not need provider-specific networking.
