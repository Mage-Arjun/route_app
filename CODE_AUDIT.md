# RouteOS code audit

This is the short, human-readable guide for future maintenance. A comment is
useful when it explains *why* something is done or how two layers fit
together. Repeating `// create a button` above every button would make the
code harder to scan, so UI labels and obvious widget construction are left
self-explanatory.

## What was checked

- 33 Flutter Dart files under `route_os/lib`.
- 26 backend Python files under `backend`.
- Android build configuration and runtime permissions.
- API models, request schemas, migrations, role checks, GPS upload flow, and
  route/map screens.
- Flutter analyzer, Flutter tests, backend tests, Python compilation, and an
  Android debug build.

## Current verification

- Flutter widget tests pass.
- Backend tests pass.
- Android debug APK builds successfully.
- Analyzer has no compile errors. Remaining notices are mostly deprecated
  `withOpacity`/`DropdownButtonFormField.value` APIs and one unused legacy
  driver route-dialog method; they do not block the build.

## Route creation in plain language

1. An operator opens **Routes → Add**.
2. **Open route planner** opens the map editor.
3. Search a city/address, tap the map to add waypoints, or record the route
   with GPS.
4. **Follow roads** converts manually placed waypoints into a road-following
   path when the routing service can find one.
5. **Use route** returns the path to the form.
6. **Save** sends the route and its ordered GeoJSON-style coordinates to the
   backend.
7. A driver sees routes assigned to them or not yet claimed, then claims one
   when starting a trip.

The route line is stored as `[longitude, latitude]` pairs in `routes.geometry`.
Keeping this format in the database means the admin map, route details, and
driver screen all render the same path.

## External map services

Place search uses the backend proxy at `/geo/search`; road following uses
`/geo/route`. Both are deliberately behind the backend so a provider can be
replaced later without changing every Flutter screen. Public geocoding and
routing services have rate limits; production deployments should eventually
configure a dedicated provider and credentials.
