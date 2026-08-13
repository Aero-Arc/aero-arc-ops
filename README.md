# Aero Arc Ops

Aero Arc Ops is a Flutter operations dashboard for monitoring distributed aerial infrastructure. The app presents a command-center view of relay health, agent activity, service registration, compute node utilization, and live telemetry in a responsive dark interface.

![Aero Arc Ops dashboard overview](assets/dashboard.png)

## Goal

Provide operators with a fast, readable surface for understanding whether the Aero Arc network is healthy and where attention is needed. The primary readiness, aircraft, operations, preflight, conformance, maintenance, records, intent, and aircraft-map views consume typed Aero Arc API read models.

## Current Functionality

- **Responsive shell** with desktop sidebar navigation and a mobile drawer.
- **System overview** with status cards, latency and throughput charts, node heartbeats, and recent events.
- **Relay monitoring** with relay counts, health states, node counts, regions, message rates, and heartbeat freshness.
- **Aircraft fleet view** with durable identity, readiness, active intent, registry placement, and telemetry recency.
- **Live operations view** with connected/stale/offline/unmapped state and independently timestamped position, battery, vehicle, system, HUD, extended-state, and GPS samples.
- **Aircraft map** that combines replay, operational volumes, conformance evidence, and live state while degrading safely if registry or telemetry state is unavailable.
- **Compute nodes** with CPU, memory, disk, region, uptime, and per-node utilization bars.
- **Telemetry dashboard** with latency, throughput, error rate, uptime, trend charts, system health radar, and fleet activity.
- **Events and settings placeholders** for timeline review and environment configuration workflows.

## Tech Stack

- Flutter 3.41+
- Dart 3.11+
- Material 3
- Custom `CustomPainter` charts
- Multi-platform Flutter project targets: web, Android, iOS, macOS, Linux, and Windows

## Quick Start

```sh
flutter pub get
flutter run -d chrome --dart-define=AERO_ARC_API_BASE_URL=http://localhost:8080
```

For another target, replace `chrome` with an available device from:

```sh
flutter devices
```

## Verify

Run the local checks before pushing changes:

```sh
flutter analyze
flutter test
flutter build web --release
```

## Project Layout

```text
lib/
  api/
    aero_arc_api.dart        # Typed HTTP client and configurable API origin
  models/
    aero_arc_models.dart     # Workflow and dashboard read models
    live_aircraft_state.dart # Registry plus independent telemetry groups
  main.dart                  # App shell, theme, routing, responsive navigation
  pages/
    overview_page.dart       # System status, charts, heartbeats, event summary
    relays_page.dart         # Relay health and operational status
    agents_page.dart         # Agent fleet table and mission state
    registry_page.dart       # Live Operations and intent posture
    aircraft_map_screen.dart # Live state, replay, intent, and conformance map
    nodes_page.dart          # Compute node health and utilization
    telemetry_page.dart      # Performance metrics and custom charts
    events_page.dart         # Events placeholder
    settings_page.dart       # Settings placeholder
  widgets/
    section_page.dart        # Shared placeholder page layout
```

## Live aircraft data contract

The Operations page reads `live_aircraft` from `GET /api/v1/operations` so a
fleet refresh is a single API request. Aircraft detail reads
`GET /api/v1/aircraft/{aircraft_id}/state` alongside the existing map endpoint.

Registry status and telemetry status are intentionally distinct. Every MAVLink
group retains its own `recorded_at` and `fresh`/`stale` status; missing groups
remain missing rather than being filled from an unrelated message. The UI uses
the API's configured freshness classification and shows each group's sample
age. See `test/fixtures/live_aircraft_state.json` for an executable example.

If the live-state request fails, the aircraft map continues to render durable
aircraft, replay, intent, volume, and conformance data with an explicit
unavailable state.

## Roadmap

- Add authenticated API sessions and role-aware controls.
- Add event filtering, severity grouping, and timeline drill-downs.
- Add relay and agent detail pages backed by registry read endpoints.
- Add golden tests for responsive dashboard layouts.

## Repository Notes

Generated build output, local editor files, Flutter tool caches, and machine-specific platform files are ignored. Source, platform scaffolding, assets, tests, and `pubspec.lock` are tracked so the app can be reproduced consistently.
