import asyncio
from datetime import datetime
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Footer, Header, Static, TabbedContent, TabPane, DataTable, Button, Input, Select
from textual.screen import ModalScreen
from textual.binding import Binding
from tui_api import BackendClient

class RouteOSTui(App):
    CSS = """
    Screen { background: #07111f; color: #d8e4f0; }
    Header { background: #0c1b2d; color: #61e6b1; }
    Footer { background: #0c1b2d; }
    .status { height: 3; border: round #24415c; padding: 1; margin: 1; color: #a8bad0; }
    .connection { height: 3; border: round #61e6b1; padding: 1; margin: 0 1 1 1; color: #61e6b1; }
    .panel { border: round #24415c; padding: 1; margin: 1; }
    DataTable { height: 1fr; border: round #24415c; margin: 1; }
    TabbedContent { height: 1fr; }
    """
    BINDINGS = [Binding("d", "page('dashboard')", "Dashboard"), Binding("p", "page('people')", "People"), Binding("v", "page('vehicles')", "Vehicles"), Binding("j", "page('journeys')", "Journeys"), Binding("l", "page('locations')", "Locations"), Binding("e", "page('events')", "Events"), Binding("a", "page('alerts')", "Alerts"), Binding("s", "page('system')", "System"), Binding("x", "resolve_alert", "Resolve alert"), Binding("c", "journey_command", "Journey action"), Binding("P", "assign_person", "Assign person"), Binding("u", "unassign_person", "Unassign person"), Binding("V", "assign_vehicle", "Assign vehicle"), Binding("n", "create_location", "New location"), Binding("t", "set_destination", "Set destination"), Binding("m", "toggle_automation", "Toggle automation"), Binding("r", "refresh", "Refresh"), Binding("q", "quit", "Quit")]

    def __init__(self, backend_url=None):
        super().__init__(); self.client = BackendClient(backend_url); self.data = {}; self.system_status = {}; self.network = {}; self.connected = False

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield Static("Connecting to RouteOS…", id="status", classes="status")
        yield Static("Backend address will appear here…", id="connection", classes="connection")
        with TabbedContent(initial="dashboard"):
            with TabPane("Dashboard", id="dashboard"): yield DataTable(id="dashboard_table")
            with TabPane("People", id="people"): yield DataTable(id="people_table")
            with TabPane("Vehicles", id="vehicles"): yield DataTable(id="vehicles_table")
            with TabPane("Journeys", id="journeys"): yield DataTable(id="journeys_table")
            with TabPane("Locations", id="locations"): yield DataTable(id="locations_table")
            with TabPane("Events", id="events"): yield DataTable(id="events_table")
            with TabPane("Alerts", id="alerts"): yield DataTable(id="alerts_table")
            with TabPane("System", id="system"): yield DataTable(id="system_table")
        yield Footer()

    async def on_mount(self):
        for table_id in ("dashboard_table", "people_table", "vehicles_table", "journeys_table", "locations_table", "events_table", "alerts_table", "system_table"):
            self.query_one(f"#{table_id}", DataTable).cursor_type = "row"
        try: await self.client.login()
        except Exception: pass
        await self.refresh_data()
        self.run_worker(self._listen_for_events(), exclusive=False)
        self.set_interval(5, self.refresh_data)

    async def _listen_for_events(self):
        while True:
            try:
                async for _message in self.client.listen():
                    await self.refresh_data()
            except Exception:
                await asyncio.sleep(2)

    async def refresh_data(self):
        try:
            self.data = await self.client.dashboard(); status = await self.client.status(); self.system_status = status; self.network = status.get("network", await self.client.network()); self.connected = True
            self.data["locations"] = await self.client.get("/locations")
            self.data["events"] = await self.client.get("/events?limit=50")
            self.query_one("#status", Static).update(f"SERVER ● ONLINE   DATABASE ● CONNECTED   EVENT ENGINE ● {status['event_engine'].upper()}   AUTOMATION ● {status['automation'].upper()}   LAST EVENT ● {status.get('last_event') or 'none'}")
            lan_urls = self.network.get("lan_urls") or []
            connection = "  ·  ".join(lan_urls) if lan_urls else self.network.get("localhost_url", "unavailable")
            self.query_one("#connection", Static).update(f"CONNECT THIS APP TO: {connection}   ·   Use this URL on the login screen")
            self._fill_tables()
        except Exception:
            self.connected = False; self.query_one("#status", Static).update("CONNECTION LOST   Showing last known state   Press R to retry")
            self.query_one("#connection", Static).update("Backend address unavailable   ·   Press R to retry")

    def _fill_tables(self):
        people = self._table("people_table", [("ID", "identifier"), ("Name", "name"), ("Status", "status"), ("Vehicle", "vehicle"), ("Location", "location")], self.data.get("people", []))
        vehicles = self._table("vehicles_table", [("ID", "identifier"), ("Name", "name"), ("Status", "status"), ("People", "people_count"), ("Last seen", "last_seen")], self.data.get("vehicles", []))
        journeys = self._table("journeys_table", [("ID", "identifier"), ("Vehicle", "vehicle"), ("People", "people"), ("Origin", "origin"), ("Destination", "destination"), ("Status", "status")], self.data.get("journeys", []))
        self._table("locations_table", [("Code", "code"), ("Name", "name"), ("People", "people_count"), ("Vehicles", "vehicles_count")], self.data.get("locations", []))
        self._table("events_table", [("Time", "timestamp"), ("Type", "event_type"), ("Entity", "entity_type"), ("Source", "source")], self.data.get("events", []))
        alerts = self._table("alerts_table", [("Severity", "severity"), ("Alert", "message"), ("Status", "status")], self.data.get("alerts", []))
        system = self.query_one("#system_table", DataTable); system.clear(columns=True); system.add_columns("System", "Value")
        system_rows = [(str(key).replace("_", " ").title(), str(value)) for key, value in self.system_status.items() if key != "network"]
        system_rows += [("Listening", f"{self.network.get('bind_host')}:{self.network.get('port')}"), ("Local", self.network.get("localhost_url", "—")), ("LAN", ", ".join(self.network.get("lan_urls", [])) or "unavailable"), ("WebSocket", ", ".join(self.network.get("websocket_urls", [])) or "unavailable")]
        system.add_rows(system_rows)
        dash = self.query_one("#dashboard_table", DataTable); dash.clear(columns=True); dash.add_columns("Metric", "Value")
        dash.add_rows([(label, str(value)) for label, value in [("People", len(people)), ("Vehicles", len(vehicles)), ("Journeys", len(journeys)), ("Active alerts", len([a for a in alerts if a.get('status') == 'active']))]])

    def _table(self, table_id, columns, rows):
        table = self.query_one(f"#{table_id}", DataTable); table.clear(columns=True); table.add_columns(*(label for label, _ in columns))
        table.add_rows([tuple(str(row.get(key, "—")) for _, key in columns) for row in rows]); return rows

    def action_page(self, page: str): self.query_one(TabbedContent).active = page
    async def action_refresh(self): await self.refresh_data()

    def _feedback(self, message: str):
        self.query_one("#status", Static).update(message)

    async def action_resolve_alert(self):
        table = self.query_one("#alerts_table", DataTable)
        row = table.cursor_row
        alerts = self.data.get("alerts", [])
        if row < 0 or row >= len(alerts):
            self._feedback("Select an alert first")
            return
        alert = alerts[row]
        if alert.get("status") != "active":
            self._feedback("Selected alert is already resolved")
            return
        try:
            await self.client.command("RESOLVE_ALERT", {"alert_id": alert["id"]})
            self._feedback(f"Resolved alert {alert['id']}")
            await self.refresh_data()
        except Exception as error:
            self._feedback(f"Action failed: {error}")

    async def action_toggle_automation(self):
        command = "DISABLE_AUTOMATION" if self.system_status.get("automation") == "running" else "ENABLE_AUTOMATION"
        try:
            await self.client.command(command)
            await self.refresh_data()
        except Exception as error:
            self._feedback(f"Action failed: {error}")

    async def action_journey_command(self):
        table = self.query_one("#journeys_table", DataTable)
        row = table.cursor_row
        journeys = self.data.get("journeys", [])
        if row < 0 or row >= len(journeys):
            self._feedback("Select a journey first")
            return
        journey = journeys[row]
        command = {"planned": "START_JOURNEY", "assigned": "START_JOURNEY", "active": "PAUSE_JOURNEY", "paused": "RESUME_JOURNEY", "arrived": "STOP_JOURNEY"}.get(journey.get("status"))
        if not command:
            self._feedback(f"No action for {journey.get('status', 'unknown')} journey")
            return
        try:
            await self.client.command(command, {"journey_id": journey["id"]})
            self._feedback(f"{command.replace('_', ' ').title()} submitted")
            await self.refresh_data()
        except Exception as error:
            self._feedback(f"Action failed: {error}")

    async def _selected_journey(self):
        rows = self.data.get("journeys", [])
        index = self.query_one("#journeys_table", DataTable).cursor_row
        if index < 0 or index >= len(rows):
            self._feedback("Select a journey first")
            return None
        return rows[index]

    async def _form(self, title, fields, options=()):
        return await self.push_screen_wait(FormScreen(title, fields, options))

    async def action_assign_person(self):
        journey = await self._selected_journey()
        if not journey: return
        people = [p for p in self.data.get("people", []) if not p.get("journey_id")]
        if not journey.get("vehicle_id"):
            self._feedback("Assign a vehicle before assigning people")
            return
        choice = await self._form("Assign person", [("person_id", "Person")], [(p["id"], f'{p["identifier"]} · {p["name"]}') for p in people])
        if choice:
            try:
                await self.client.command("ASSIGN_PERSON", {"person_id": int(choice["person_id"]), "vehicle_id": journey["vehicle_id"]})
                await self.refresh_data()
            except Exception as error: self._feedback(f"Action failed: {error}")

    async def action_unassign_person(self):
        journey = await self._selected_journey()
        if not journey: return
        people = journey.get("people", [])
        choice = await self._form("Unassign person", [("person_id", "Person")], [(p["id"], f'{p["identifier"]} · {p["name"]}') for p in people])
        if choice:
            try:
                await self.client.command("UNASSIGN_PERSON", {"person_id": int(choice["person_id"])})
                await self.refresh_data()
            except Exception as error: self._feedback(f"Action failed: {error}")

    async def action_assign_vehicle(self):
        journey = await self._selected_journey()
        if not journey: return
        vehicles = [v for v in self.data.get("vehicles", []) if not v.get("journey_id") or v.get("id") == journey.get("vehicle_id")]
        choice = await self._form("Assign vehicle", [("vehicle_id", "Vehicle")], [(v["id"], f'{v["identifier"]} · {v["name"]}') for v in vehicles])
        if choice:
            try:
                await self.client.command("ASSIGN_VEHICLE", {"journey_id": journey["id"], "vehicle_id": int(choice["vehicle_id"])})
                await self.refresh_data()
            except Exception as error: self._feedback(f"Action failed: {error}")

    async def action_create_location(self):
        fields = [("code", "Code"), ("name", "Name"), ("type", "Type"), ("latitude", "Latitude"), ("longitude", "Longitude")]
        choice = await self._form("Create location", fields)
        if choice:
            try:
                await self.client.command("CREATE_LOCATION", choice)
                await self.refresh_data()
            except Exception as error: self._feedback(f"Action failed: {error}")

    async def action_set_destination(self):
        journey = await self._selected_journey()
        if not journey: return
        locations = self.data.get("locations", [])
        choice = await self._form("Set destination", [("location_id", "Location")], [(x["id"], f'{x["code"]} · {x["name"]}') for x in locations])
        if choice:
            try:
                await self.client.command("SET_DESTINATION", {"journey_id": journey["id"], "location_id": int(choice["location_id"])})
                await self.refresh_data()
            except Exception as error: self._feedback(f"Action failed: {error}")


class FormScreen(ModalScreen):
    CSS = "Screen { align: center middle; } #form { width: 70; height: auto; padding: 2; border: round $accent; background: $surface; } Input, Select, Button { margin: 1 0; }"

    def __init__(self, title, fields, options=()):
        super().__init__()
        self.title_text, self.fields, self.options = title, fields, options

    def compose(self):
        yield Vertical(id="form")

    def on_mount(self):
        form = self.query_one("#form", Vertical)
        form.mount(Static(self.title_text))
        for key, label in self.fields:
            if key.endswith("_id"):
                form.mount(Select(list(self.options), prompt=label, id=key))
            else:
                form.mount(Input(placeholder=label, id=key))
        form.mount(Horizontal(Button("Cancel", id="cancel"), Button("Submit", variant="primary", id="submit")))

    def on_button_pressed(self, event):
        if event.button.id == "cancel":
            self.dismiss(None)
            return
        values = {}
        for key, _ in self.fields:
            widget = self.query_one(f"#{key}")
            value = widget.value
            if value is None or str(value).strip() == "":
                self.notify(f"{key} is required", severity="error")
                return
            values[key] = value
        self.dismiss(values)


if __name__ == "__main__": RouteOSTui().run()
