# Flutter code guide

The Flutter app is split by responsibility rather than by widget type.

- `screens/` owns user interaction and presentation.
- `services/` owns external communication and device APIs.
- `models/` owns JSON-to-Dart conversion.
- `providers/` owns app state shared by multiple screens.
- `config/` owns cross-cutting configuration and styling.

If a screen needs backend data, call a named method on `ApiService`; do not
create a second `Dio` client in the screen. If two screens need the same
display logic, extract a small widget beside those screens or into
`screens/shared/`.

The backend contract is the source of truth for field names and endpoint paths.
When a backend response changes, update the model and service together.
