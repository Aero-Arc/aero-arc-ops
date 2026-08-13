# Aero Arc Ops contributor context

## Repository purpose

This Flutter application is the operator console for the Aero Arc API. It is
not the public `aero-arc-web` marketing site. Keep operational UI work in this
repository and preserve the dark, dense command-center visual language.

## Architecture

- `lib/api/aero_arc_api.dart` is the HTTP boundary. The base URL is supplied at
  build time with `--dart-define=AERO_ARC_API_BASE_URL=...`.
- `lib/models/aero_arc_models.dart` contains durable workflow/read-model DTOs.
- `lib/models/live_aircraft_state.dart` contains the independently timestamped
  registry and MAVLink telemetry groups used for live operations.
- `lib/pages/registry_page.dart` is the Operations page despite its historical
  filename. It consumes the batch `GET /api/v1/operations` read model.
- `lib/pages/aircraft_map_screen.dart` combines the historical map endpoint with
  `GET /api/v1/aircraft/{aircraft_id}/state`. A failure of the live-state call
  must not hide map history, intent, or conformance data.
- `lib/widgets/dashboard_ui.dart` owns shared loading, error, empty, status, and
  detail-sheet components.

## Live-state contract

- Registry connection and telemetry availability are separate statuses.
- Position, battery, vehicle heartbeat, system, HUD, extended-state, and GPS
  messages are separate samples. Never imply they share a timestamp.
- Render the API-provided `fresh`, `stale`, `missing`, and `unavailable` states;
  do not recreate freshness thresholds in the client.
- Render `connected`, `stale`, `offline`, `unmapped`, and `unavailable`
  connection states explicitly. `connected: true` alone is not sufficient.
- Missing optional groups are expected and must not make the whole page fail.
- Use the operations batch response for list views; do not add an N+1 request
  per aircraft.

## Testing and quality

Run:

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
```

Tests use `http/testing.dart` at the client boundary and checked-in JSON under
`test/fixtures/` for API contract coverage. Widget tests should cover partial
failure, empty, stale/offline, and responsive behavior without network tiles.

The project currently targets Flutter 3.41+ / Dart 3.11+. Older local Flutter
SDKs may reject APIs such as `DropdownButtonFormField.initialValue`; use the
repository toolchain before changing compatible source to satisfy an old SDK.
