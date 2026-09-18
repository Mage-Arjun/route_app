# Admin screen guide

Each file owns one visible part of the operator/admin experience:

- `dashboard_screen.dart`: summary cards and shortcuts.
- `route_list_screen.dart`: route list and add-route entry point.
- `route_form_screen.dart`: route details, assignments, and final save.
- `route_builder_screen.dart`: search, tap-to-draw, and GPS recording.
- `route_detail_screen.dart`: saved route line, stops, editing, and analytics.
- `map_screen.dart`: live vehicle positions from the backend.
- `live_tracking_screen.dart`: live vehicle status list and refresh state.
- `customer_*`: customer records used as delivery stops.
- `vehicle_*`: fleet records used for driver assignment and GPS updates.

Keep network calls in `ApiService`, response conversion in a model, and role
checks in the backend as well as the UI. The UI is a convenience boundary; it
is not the security boundary.
