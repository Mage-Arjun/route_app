# RouteOS Backend Rebuild --- Codex Master Specification

## Driver state contract

The seeded driver accounts are `driver1@routeos.local` / `driver123` and
`driver2@routeos.local` / `driver123`. They are linked persistently to driver
people and their assigned vehicles/journeys.

Build 1 accounts are imported automatically by `routeos.sh` when the sibling
database is available. The imported demo logins are:

- `admin@routeapp.com` / `admin123` (admin)
- `arun@routeapp.com`, `rahul@routeapp.com`, `suresh@routeapp.com`,
  `manoj@routeapp.com`, `anvar@routeapp.com` / `driver123` (drivers)
- `deepa@routeapp.com` / `supervisor123` (operator)

Authenticated driver clients use `GET /driver/me`. The endpoint follows the
authenticated user's `person_id` and that person's current vehicle/journey;
it never selects an arbitrary journey from the global list. Missing
assignment is returned as a successful response with explicit null fields and
`operational_status: "unassigned"`. Driver journey commands are limited to
the assigned journey and are validated by the backend state machine.

## Mission

Rebuild the current RouteOS backend into a small, coherent, event-driven
operations server with a native terminal operator console.

This is a **backend-first rebuild**. Do not attempt to preserve the
existing backend architecture simply because it already exists.

The existing project is reference material. Reuse useful domain ideas,
authentication concepts, demo data where appropriate, and working pieces
only when they fit the new architecture.

The finished system must be runnable by an inexperienced operator with:

``` bash
./routeos.sh
```

## Importing Build 1 data

The new backend includes a read-only, repeatable converter for the Build 1
SQLite database. Run it from this directory after migrations have completed:

``` bash
python import_build1.py
```

It translates Build 1 customers into tracked people and locations, routes into
journeys, route stops into assignments, driver accounts into authenticated
driver identities, and trip history into events. Pending route changes become
RouteOS alerts. The source database is never modified, and repeated runs do
not duplicate imported records.

That single command must prepare the environment, initialize/migrate the
database, start the backend, verify that it is healthy, and launch the
terminal UI. The operator must not need to manually run uvicorn,
alembic, database commands, or Python modules.

------------------------------------------------------------------------

# 1. Product definition

RouteOS is an **automated operations monitoring and control system**.

The backend is the core product.

The terminal UI is an operator console attached to it.

The system tracks:

-   people
-   vehicles
-   locations
-   journeys
-   assignments
-   events
-   alerts
-   system state

The central operational questions are:

1.  Who is currently inside the system?
2.  Who entered?
3.  Who left?
4.  Who is travelling?
5.  Who is travelling with whom?
6.  Which vehicle is carrying which people?
7.  Where is a person/vehicle?
8.  Where are they going?
9.  What happened recently?
10. What requires operator attention?
11. What can the operator control?
12. What is the current health of the server and automation engine?

This is deliberately different from the old route-centric delivery
application.

The new architecture is **activity-centric and event-driven**.

------------------------------------------------------------------------

# 2. Existing backend: inspect before modifying

The current backend contains approximately:

``` text
backend/
├── main.py
├── config.py
├── database.py
├── models.py
├── schemas.py
├── auth.py
├── routers/
│   ├── analytics.py
│   ├── customers.py
│   ├── routes.py
│   ├── trips.py
│   ├── users.py
│   └── vehicles.py
├── services/
│   └── route_optimizer.py
├── seed.py
├── test_api.py
└── alembic/
```

Important known issues:

-   `routes.py` and `schemas.py` are excessively large.
-   The old application is strongly centered around
    customers/routes/trips.
-   Live locations are currently held in an in-memory dictionary in the
    old application.
-   The existing Alembic initial migration contains no actual schema
    operations.
-   The old frontend is broken and will be rebuilt separately.
-   Do not carry over dead, redundant, mobile-specific, or
    delivery-specific functionality merely because it exists.
-   Inspect the current files and dependency versions before
    implementation.
-   Do not copy `.venv`, `__pycache__`, generated files, or other build
    artifacts into the new architecture.

The existing backend is a reference, not the specification.

------------------------------------------------------------------------

# 3. Non-negotiable architecture

Use:

-   Python
-   FastAPI
-   SQLAlchemy
-   Alembic
-   SQLite by default
-   PostgreSQL compatibility through configuration
-   WebSockets for real-time updates
-   Textual for the terminal UI
-   a single `routeos.sh` launcher

Do not introduce Redis, Kafka, Celery, Docker, Kubernetes, or other
infrastructure unless there is a concrete requirement that cannot be
solved without it.

The first deployment must remain simple.

------------------------------------------------------------------------

# 4. Architectural principle

The system must follow:

``` text
INPUT
  ↓
EVENT
  ↓
EVENT ENGINE
  ↓
STATE ENGINE
  ↓
AUTOMATION/RULE ENGINE
  ↓
PERSISTENCE
  ↓
REAL-TIME BROADCAST
  ↓
TUI/API CLIENTS
```

Operator commands must follow:

``` text
TUI/API
  ↓
COMMAND
  ↓
VALIDATION/AUTHORIZATION
  ↓
EVENT
  ↓
STATE ENGINE
  ↓
AUTOMATION
  ↓
PERSISTENCE
  ↓
BROADCAST
```

Do not allow the TUI to directly manipulate database records.

Do not put business logic in Textual widgets.

Do not make the API a second business-logic implementation.

There must be one authoritative application core.

------------------------------------------------------------------------

# 5. Core entities

Start with these entities.

## Person

Represents a tracked person.

Fields should include the minimum necessary:

-   id
-   identifier
-   name
-   status
-   current location
-   current journey where applicable
-   current vehicle where applicable
-   created_at
-   updated_at

Do not store redundant derived information unless there is a
demonstrated performance reason.

## Vehicle

Fields:

-   id
-   identifier
-   name
-   type
-   status
-   current latitude
-   current longitude
-   current location where applicable
-   current journey where applicable
-   last_seen
-   created_at
-   updated_at

## Location

Fields:

-   id
-   code
-   name
-   type
-   latitude
-   longitude
-   status
-   created_at
-   updated_at

Locations are named operational places such as:

``` text
GATE_A
DEPOT
WAREHOUSE
KOCHI
MUNNAR
KOTTAYAM
```

## Journey

Represents an actual movement from an origin toward a destination.

Fields:

-   id
-   identifier
-   vehicle_id
-   origin_location_id
-   destination_location_id
-   status
-   started_at
-   arrived_at
-   completed_at
-   created_at
-   updated_at

Suggested statuses:

``` text
planned
active
arrived
completed
cancelled
paused
```

## Assignment

Represents a person's association with a journey/vehicle.

Fields:

-   id
-   person_id
-   journey_id
-   vehicle_id
-   joined_at
-   left_at
-   status

This should allow historical relationships.

## Event

The central historical record.

Fields:

-   id
-   event_type
-   entity_type
-   entity_id
-   timestamp
-   actor_id where applicable
-   location_id where applicable
-   source
-   payload
-   created_at

Payload may be JSON.

Events should be treated as operational facts. Do not casually mutate
historical events.

Suggested event types:

``` text
PERSON_ENTERED
PERSON_EXITED
PERSON_ENTERED_VEHICLE
PERSON_EXITED_VEHICLE

VEHICLE_ENTERED_LOCATION
VEHICLE_EXITED_LOCATION
VEHICLE_LOCATION_UPDATED
VEHICLE_DEPARTED
VEHICLE_ARRIVED

JOURNEY_CREATED
JOURNEY_STARTED
JOURNEY_PAUSED
JOURNEY_RESUMED
JOURNEY_ARRIVED
JOURNEY_COMPLETED
JOURNEY_CANCELLED

PERSON_ASSIGNED
PERSON_UNASSIGNED
VEHICLE_ASSIGNED

ALERT_CREATED
ALERT_RESOLVED

SYSTEM_STARTED
SYSTEM_STOPPING
AUTOMATION_ENABLED
AUTOMATION_DISABLED
```

The exact event list may be refined during implementation.

## Alert

Fields:

-   id
-   severity
-   alert_type
-   entity_type
-   entity_id
-   message
-   status
-   created_at
-   resolved_at
-   resolved_by
-   metadata/payload

Suggested alert types:

``` text
GPS_STALE
UNEXPECTED_EXIT
UNKNOWN_PERSON
UNASSIGNED_PERSON
ROUTE_DEVIATION
VEHICLE_STATIONARY_TOO_LONG
SYSTEM_ERROR
```

## Operator/User

Retain authentication, but simplify it around the actual product.

Minimum:

-   id
-   username/email
-   password hash
-   role
-   status
-   created_at
-   updated_at

Roles can begin as:

``` text
admin
operator
viewer
```

Do not recreate the old driver-oriented permission system unless the new
requirements explicitly need it.

------------------------------------------------------------------------

# 6. Runtime state

Persistent database state and runtime state are different.

Runtime state may contain:

-   current operational state cache
-   active WebSocket clients
-   event subscribers
-   server uptime
-   event engine status
-   automation engine status
-   last event timestamp
-   temporary automation state

Runtime state must be reconstructable after restart.

Do NOT use the old pattern:

``` python
_live_locations = {}
```

as the authoritative location store.

Location state must be persisted appropriately, and runtime caches must
be disposable.

------------------------------------------------------------------------

# 7. Event engine

Implement an internal event processing service.

Conceptually:

``` python
event = create_event(...)
event_engine.publish(event)
```

The event engine should:

1.  validate the event
2.  persist the event
3.  update operational state
4.  execute relevant automation rules
5.  create derived events/alerts where necessary
6.  broadcast changes to connected clients

Avoid recursive infinite event loops.

Use clear event-processing boundaries.

If a rule generates an event, mark it as system-generated.

------------------------------------------------------------------------

# 8. State engine

The state engine maintains the current operational picture.

Examples:

### Person enters vehicle

Input:

``` text
PERSON_ENTERED_VEHICLE
P017
VEH04
```

Result:

``` text
P017.current_vehicle = VEH04
P017.current_journey = J102
P017.state = travelling
```

If VEH04 is travelling to KOCHI:

``` text
P017.destination = KOCHI
```

The operator should not have to manually establish all of these
relationships.

### Person exits vehicle

Update the current state and assignment history.

### Vehicle location update

Update:

-   latitude
-   longitude
-   last_seen
-   location if a known location is detected
-   journey state where appropriate

------------------------------------------------------------------------

# 9. Automation engine

Implement explicit, understandable rules.

Examples:

## GPS stale

``` text
IF current_time - vehicle.last_seen > configured threshold
THEN create GPS_STALE alert
```

## Journey arrival

``` text
IF active vehicle reaches destination location
THEN journey becomes arrived
AND emit JOURNEY_ARRIVED
```

## Unexpected exit

``` text
IF person exits a vehicle/journey
AND the exit was not expected
THEN create UNEXPECTED_EXIT
```

## Missing destination

``` text
IF active person/journey has no destination
THEN create UNASSIGNED_PERSON or equivalent alert
```

Rules must be configurable where practical.

Avoid hardcoding dozens of unrelated business rules.

The automation engine must be pausable/enabled/disabled from the System
interface.

------------------------------------------------------------------------

# 10. Commands

Create a central command layer.

Examples:

``` text
START_JOURNEY
PAUSE_JOURNEY
RESUME_JOURNEY
STOP_JOURNEY
ASSIGN_PERSON
UNASSIGN_PERSON
ASSIGN_VEHICLE
SET_DESTINATION
CREATE_LOCATION
RESOLVE_ALERT
ENABLE_AUTOMATION
DISABLE_AUTOMATION
REFRESH_STATE
```

Every command must:

1.  authenticate/authorize
2.  validate input
3.  perform the operation through the application core
4.  generate the appropriate event
5.  update state
6.  persist changes
7.  notify connected clients

The TUI should invoke commands, not manipulate SQLAlchemy models
directly.

------------------------------------------------------------------------

# 11. API

Keep the external API small and coherent.

Suggested top-level endpoints:

``` text
/auth
/people
/vehicles
/locations
/journeys
/events
/alerts
/system
/commands
```

Required infrastructure:

``` text
GET /health
GET /system/status
GET /system/state
WebSocket /ws
```

The API should provide initial state to the TUI.

The WebSocket should then provide real-time changes.

------------------------------------------------------------------------

# 12. Real-time protocol

The TUI needs one stable WebSocket connection.

The server may broadcast messages such as:

``` json
{
  "type": "event",
  "event_type": "PERSON_ENTERED_VEHICLE",
  "entity_type": "person",
  "entity_id": 17,
  "timestamp": "...",
  "payload": {
    "vehicle_id": 4
  }
}
```

or:

``` json
{
  "type": "state_changed",
  "entity_type": "vehicle",
  "entity_id": 4,
  "changes": {
    "status": "moving",
    "latitude": 11.25,
    "longitude": 75.78
  }
}
```

or:

``` json
{
  "type": "alert",
  "action": "created",
  "alert": { ... }
}
```

The protocol must be documented in code comments and/or a dedicated
protocol section.

------------------------------------------------------------------------

# 13. Database

Default:

``` text
SQLite
```

Use a local database file under a sensible data directory.

Enable SQLite WAL mode where appropriate.

Make the database URL configurable.

The code should also support PostgreSQL through the same SQLAlchemy
abstraction.

Do not require PostgreSQL for local/demo operation.

Use real Alembic migrations.

The initial migration must actually create the schema.

Do not leave:

``` python
def upgrade():
    pass
```

------------------------------------------------------------------------

# 14. Seed data

Create a new deterministic demo seed.

The old Kozhikode demo data can be reused selectively, but the new seed
should represent the new domain.

Include enough data to make the TUI visually useful immediately:

-   at least 20 people
-   at least 8 vehicles
-   several named locations
-   several active journeys
-   people assigned to vehicles
-   a few idle vehicles
-   several historical events
-   at least two active alerts
-   at least one resolved alert
-   at least one journey with multiple people

Do not use random data on every launch.

Seed should be deterministic.

Running the seed repeatedly should not duplicate data.

Protect production environments from accidental seeding.

------------------------------------------------------------------------

# 15. Authentication

Implement simple robust authentication.

Requirements:

-   password hashing
-   JWT or similarly appropriate signed session token
-   role checking
-   protected API endpoints
-   secure secret configuration
-   no plaintext passwords in source
-   `.env.example` containing required settings

Default development/demo credentials may be documented.

Do not hardcode production secrets.

------------------------------------------------------------------------

# 16. Server startup

The Python backend must expose a clean application entry point.

The server should have:

``` text
startup
shutdown
health
```

Startup should initialize:

-   database
-   runtime state
-   event engine
-   automation engine

Shutdown should cleanly stop:

-   automation workers
-   event workers
-   WebSocket infrastructure
-   database resources

No orphan processes.

------------------------------------------------------------------------

# 17. Textual TUI

Use Textual.

The TUI is the native operator console.

It must connect to the backend through:

``` text
HTTP localhost
+
WebSocket localhost
```

Do not duplicate backend business logic inside the TUI.

The TUI is responsible for:

-   presentation
-   navigation
-   operator interaction
-   API/WebSocket communication
-   local UI state

------------------------------------------------------------------------

# 18. TUI shell

Every page must share a consistent shell:

``` text
┌──────────────────────────────────────────────────────────────┐
│ ROUTEOS CONTROL                    SERVER ● ONLINE  17:42:31 │
├────────────────┬─────────────────────────────────────────────┤
│ DASHBOARD      │                                             │
│ PEOPLE         │                 PAGE CONTENT                │
│ VEHICLES       │                                             │
│ JOURNEYS       │                                             │
│ LOCATIONS      │                                             │
│ EVENTS         │                                             │
│ ALERTS         │                                             │
│ SYSTEM         │                                             │
└────────────────┴─────────────────────────────────────────────┘
```

Persistent header must display:

-   server status
-   database status
-   event engine status
-   automation status
-   current time

Persistent navigation:

``` text
Dashboard
People
Vehicles
Journeys
Locations
Events
Alerts
System
```

Keyboard shortcuts:

``` text
D Dashboard
P People
V Vehicles
J Journeys
L Locations
E Events
A Alerts
S System
/ Search
R Refresh
? Help
Esc Back
Q Quit
```

Mouse support is welcome but keyboard support is mandatory.

------------------------------------------------------------------------

# 19. Dashboard page

Purpose:

Give the operator an immediate understanding of the entire system.

Must contain:

## System status

``` text
Server
Database
Event Engine
Automation
Last Event
Uptime
```

## Counters

``` text
People
Vehicles
Active Journeys
Alerts
```

## Live movement

Columns:

``` text
Person
Vehicle
Destination
Status
Last Update
```

## Recent events

Show newest operational events.

## Active alerts

Show unresolved alerts.

Selecting an entity must open its detail view.

No decorative widgets that do not communicate operational information.

------------------------------------------------------------------------

# 20. People page

Show:

``` text
ID
Name
Status
Location
Vehicle
Destination
Journey
Last Update
```

Provide:

-   search
-   status filtering
-   selection
-   detail panel
-   event history
-   links to vehicle/journey

Detail view must show the person's current operational state and recent
history.

------------------------------------------------------------------------

# 21. Vehicles page

Show:

``` text
ID
Name
Type
Status
Location
Destination
People Count
Last Update
```

Detail:

``` text
vehicle status
driver/operator if applicable
current location
coordinates
destination
journey
people currently associated
last update
recent events
```

------------------------------------------------------------------------

# 22. Journeys page

Show:

``` text
ID
Vehicle
People
Origin
Destination
Status
Start Time
Last Update
```

Detail:

``` text
origin
destination
vehicle
people
status
timeline
events
```

Provide working commands:

-   start
-   pause
-   resume
-   stop/complete
-   cancel where appropriate

Dangerous/destructive actions require confirmation.

------------------------------------------------------------------------

# 23. Locations page

Show named locations and current activity.

Columns:

``` text
Location
People
Vehicles
Activity
```

Detail:

``` text
location name
coordinates
people present
vehicles present
recent arrivals
recent departures
```

A graphical map is NOT required for the first version.

Do not introduce a mapping dependency unless explicitly requested later.

------------------------------------------------------------------------

# 24. Events page

This is the operational event history.

Show:

``` text
Time
Type
Entity
Details
Source
```

Filters:

``` text
All
People
Vehicles
Journeys
Locations
System
```

Support search.

Selecting an event shows its complete payload/metadata.

Events must be clearly distinguished from technical logs.

------------------------------------------------------------------------

# 25. Alerts page

Show:

``` text
Severity
Alert
Entity
Created
Status
```

Support:

-   active/resolved filtering
-   detail view
-   resolve action
-   related entity navigation
-   related event navigation

Never silently delete an alert.

Resolving creates an auditable action/event.

------------------------------------------------------------------------

# 26. System page

Show:

``` text
Server
Database
Event Engine
Automation
WebSocket Clients
Uptime
Last Event
Version
```

Controls:

``` text
Refresh
Enable Automation
Disable Automation
Restart/refresh event processing if safely supported
Diagnostics
Shutdown Server
```

Dangerous controls require confirmation.

Do not expose raw shell commands to the operator.

Do not require the operator to understand Python, SQL, or Linux
internals.

------------------------------------------------------------------------

# 27. TUI states

Every screen must handle:

### Loading

``` text
Loading...
```

### Empty

``` text
No people currently match the selected filter.
```

### Backend unavailable

``` text
CONNECTION LOST

Showing last known state.

[R] Retry
```

### Stale data

``` text
DATA STALE
Last successful update: 17:31:42
```

Stale data must never be visually presented as current.

### Error

Show a human-readable message and a retry/back action.

Do not dump Python tracebacks into the normal operator interface.

Technical errors belong in logs/diagnostics.

------------------------------------------------------------------------

# 28. TUI visual design

Use a professional control-room aesthetic.

Default:

-   dark terminal theme
-   high information density
-   clear borders
-   restrained accent usage
-   monospace for IDs/timestamps/system values
-   readable text for descriptions
-   status indicators
-   minimal animation
-   no fake hacker aesthetics
-   no unnecessary gradients
-   no meaningless charts
-   no oversized cards

The UI should remain useful at smaller terminal sizes.

Avoid layouts that require an extremely wide terminal.

------------------------------------------------------------------------

# 29. TUI detail pattern

Avoid creating a separate screen for every tiny object.

Use:

``` text
LIST
 ↓
SELECT
 ↓
DETAIL PANEL
 ↓
ACTION
```

For example:

``` text
PEOPLE
────────────────────────

P-017
P-023
P-031
P-044

────────────────────────
P-017 DETAILS

Status       TRAVELLING
Vehicle      VEH-04
Journey      J-102
Destination  KOCHI
Location     HIGHWAY
Last Seen    17:42:21

[E] Events
[V] Vehicle
[J] Journey
```

This keeps the TUI compact.

------------------------------------------------------------------------

# 30. Single launcher

Create:

``` text
routeos.sh
```

The script must:

1.  locate the project directory reliably
2.  check for Python
3.  create a virtual environment if missing
4.  install dependencies
5.  create required data/config directories
6.  create a local `.env` from `.env.example` when appropriate
7.  run Alembic migrations
8.  optionally initialize deterministic demo data if the database is
    empty
9.  start the FastAPI server
10. wait for `/health`
11. launch the Textual TUI
12. handle Ctrl+C and normal quit
13. terminate the backend cleanly when the TUI exits
14. remove/avoid orphaned server processes

The operator should only need:

``` bash
./routeos.sh
```

The script must work regardless of the directory from which it is
invoked.

Do not assume the current working directory is the project directory.

------------------------------------------------------------------------

# 31. Local server / remote clients

The local TUI should use:

``` text
127.0.0.1
```

by default.

The API bind address should be configurable.

Example:

``` text
HOST=0.0.0.0
PORT=8000
```

The TUI should independently know which backend URL it should use.

Do not hardcode production network addresses.

------------------------------------------------------------------------

# 32. Logging

Use Python logging with useful levels.

Example:

``` text
17:42:21 INFO  event       PERSON_ENTERED_VEHICLE
17:42:21 INFO  state       P-017 -> VEH-04
17:42:21 INFO  journey     P-017 -> KOCHI
17:42:30 WARN  automation  VEH-03 GPS stale
```

Technical logs and operational events are separate concepts.

Logs should be useful for debugging.

The TUI should not normally display raw log spam.

------------------------------------------------------------------------

# 33. Configuration

Provide:

``` text
.env.example
```

with settings such as:

``` text
APP_NAME
APP_ENV
SECRET_KEY
DATABASE_URL
HOST
PORT
TUI_BACKEND_URL
GPS_STALE_THRESHOLD
AUTOMATION_ENABLED
SEED_DEMO_DATA
```

Use sensible defaults for development.

Fail clearly when required production settings are missing or insecure.

------------------------------------------------------------------------

# 34. Tests

Do not consider the backend complete until automated tests exist.

Test at minimum:

## Database

-   migrations
-   model creation
-   relationships

## Authentication

-   login
-   invalid login
-   protected endpoint
-   role restrictions

## Events

-   event creation
-   event persistence
-   event processing

## State

-   person enters vehicle
-   person exits vehicle
-   vehicle location updates
-   journey state transitions

## Automation

-   GPS stale alert
-   journey arrival
-   unexpected exit
-   alert resolution

## Commands

-   authorized command
-   unauthorized command
-   invalid command
-   command creates expected event/state changes

## API

-   health
-   system state
-   people
-   vehicles
-   journeys
-   locations
-   events
-   alerts

## WebSocket

-   client connects
-   initial state
-   event broadcast
-   state update broadcast
-   clean disconnect

## Launcher

At least test the important shell behavior where practical.

------------------------------------------------------------------------

# 35. Acceptance test

The rebuild is NOT complete merely because Python imports successfully.

The following scenario must work:

``` text
./routeos.sh
```

Expected:

``` text
environment ready
database ready
migrations complete
backend started
health check passes
TUI launches
```

Then the TUI displays:

``` text
SERVER ● ONLINE
DATABASE ● CONNECTED
EVENT ENGINE ● RUNNING
AUTOMATION ● RUNNING
```

The dashboard displays seeded operational data.

Then create an event through the backend/API/test command:

``` text
P017 enters VEH04
```

The TUI must update without manual refresh.

The dashboard should reflect the relationship.

Then create a vehicle location update.

The TUI should update the vehicle's location/last-seen state.

Then trigger a stale GPS condition.

An alert should appear.

Resolve the alert through the TUI.

The resolution must be persisted and auditable.

Restart the server.

The persistent state must survive.

The event history must survive.

Runtime connections may disappear, but state must reconstruct correctly.

------------------------------------------------------------------------

# 36. Code organization

Prefer a small number of understandable files.

Suggested structure:

``` text
routeos/
│
├── server/
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models.py
│   ├── schemas.py
│   ├── auth.py
│   ├── events.py
│   ├── state.py
│   ├── automation.py
│   ├── commands.py
│   └── api.py
│
├── tui/
│   ├── app.py
│   ├── api.py
│   └── screens.py
│
├── migrations/
│
├── tests/
│
├── data/
│
├── .env.example
├── requirements.txt
├── routeos.sh
└── README.md
```

Do not split every class into a separate file.

Do not create empty abstraction layers.

Do not create a repository/service/factory hierarchy unless it genuinely
reduces complexity.

If a file becomes too large, split it by coherent responsibility.

------------------------------------------------------------------------

# 37. Comments

Comments are required for architectural decisions and non-obvious
behavior.

Good:

``` python
# Runtime state is intentionally reconstructable. The database remains
# authoritative so a server restart cannot erase the operational picture.
```

Bad:

``` python
# Set status to active.
status = "active"
```

Core engine files should contain clear section comments.

Use descriptive names.

Prefer straightforward code over clever code.

------------------------------------------------------------------------

# 38. What NOT to do

Do not:

-   preserve the old architecture unnecessarily
-   copy the old Flutter application's assumptions into the backend
-   build a customer/delivery ERP unless the new requirements explicitly
    restore it
-   create a giant router file containing all business logic
-   put business logic inside Textual widgets
-   use an in-memory dictionary as the authoritative data store
-   use fake API responses
-   create dead endpoints
-   create dead UI controls
-   add dependencies without justification
-   require PostgreSQL for local operation
-   require Docker for local operation
-   require Redis for local operation
-   add a map UI
-   add AI
-   add route optimization unless explicitly required
-   add background workers merely for architectural appearance
-   expose raw database manipulation to the TUI
-   expose shell commands to nontechnical operators
-   hardcode secrets
-   leave migrations empty
-   leave TODO placeholders for required functionality

------------------------------------------------------------------------

# 39. Backward compatibility

Backward compatibility with the old API is NOT a priority.

If an old endpoint conflicts with the new architecture, replace it.

If old models are irrelevant, remove them.

If old code can be safely reused, reuse it.

Do not create compatibility complexity solely to avoid deleting old
code.

------------------------------------------------------------------------

# 40. Implementation strategy

Codex is authorized to perform the backend rebuild in one pass.

Work systematically:

### Step 1

Inspect the existing backend and current repository.

### Step 2

Create the new structure.

### Step 3

Implement configuration and database.

### Step 4

Implement models and migrations.

### Step 5

Implement authentication.

### Step 6

Implement event engine.

### Step 7

Implement state engine.

### Step 8

Implement automation engine.

### Step 9

Implement command engine.

### Step 10

Implement API and WebSocket protocol.

### Step 11

Implement deterministic seed data.

### Step 12

Implement Textual TUI.

### Step 13

Implement launcher.

### Step 14

Implement tests.

### Step 15

Run the complete acceptance test.

Fix actual failures rather than stopping after the first successful
import.

------------------------------------------------------------------------

# 41. Definition of done

Codex must consider the work complete only when:

-   the old backend has been replaced/refactored into the new
    architecture
-   migrations work from an empty database
-   SQLite works out of the box
-   authentication works
-   events persist
-   state updates correctly
-   automation works
-   commands work
-   REST API works
-   WebSocket works
-   TUI connects automatically
-   dashboard works
-   People works
-   Vehicles works
-   Journeys works
-   Locations works
-   Events works
-   Alerts works
-   System page works
-   loading/empty/error/stale states work
-   seeded demo data exists
-   tests pass
-   `./routeos.sh` launches the entire system
-   quitting the TUI cleanly shuts down the locally launched backend
-   restarting the server preserves persistent state
-   no required feature is represented by a dead button or placeholder
-   no generated build artifacts or virtual environments are committed
    to the source tree

------------------------------------------------------------------------

# 42. Final instruction to Codex

Do not merely describe what should be done.

**Implement it.**

Inspect the existing repository first, then make the necessary changes.

When architectural choices are required, prefer the simplest design that
satisfies this README.

Keep the code highly structured and well commented.

Do not ask for permission to perform ordinary implementation steps.

Do not stop at scaffolding.

Do not leave a half-built application.

Run tests and the launcher after implementation and fix the failures you
encounter.

The final result should be a working local RouteOS server/operator
system that an inexperienced operator can start with:

``` bash
./routeos.sh
```

and immediately use through the terminal.

The backend is the source of truth.

The TUI is the operator's window into that backend.

The event engine, state engine, automation engine, command engine, API,
database, and TUI must operate as one coherent system.

## Delivery product surface

The same server also exposes the complete delivery workflow:

- `/customers` — searchable customer records and service locations
- `/routes` and `/routes/{id}/stops` — versioned route plans and ordered stops
- `/trips` — driver-scoped trip execution records
- `/trips/{id}/stops/{stop_id}` — arrive, complete, skip, and fail actions
- `/trips/{id}/stops/{stop_id}/pod` — validated receiver, signature, and photo proof
- `/route-changes` — auditable request/approve/reject workflow
- `/analytics/dashboard` and `/analytics/routes/{id}` — database-backed metrics
- `/users/me` and `/auth/register` — profile and account workflows

Proof images are stored with generated filenames under `data/uploads`; client
filenames are never used as paths, and image type/size validation is applied.

Run the backend test suite from a clean environment with:

```bash
./.venv/bin/pytest -q
```

The test suite uses an isolated temporary SQLite database and does not mutate
the shipped demo database.
