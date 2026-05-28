# Aero Arc Ops

Aero Arc Ops is a Flutter operations dashboard for monitoring distributed aerial infrastructure. The app presents a command-center view of relay health, agent activity, service registration, compute node utilization, and live telemetry in a responsive dark interface.

## Goal

Provide operators with a fast, readable surface for understanding whether the Aero Arc network is healthy and where attention is needed. The current app is a front-end prototype with representative operational data, reusable dashboard patterns, and room to connect real services behind each panel.

## Current Functionality

- **Responsive shell** with desktop sidebar navigation and a mobile drawer.
- **System overview** with status cards, latency and throughput charts, node heartbeats, and recent events.
- **Relay monitoring** with relay counts, health states, node counts, regions, message rates, and heartbeat freshness.
- **Agent fleet view** with callsigns, battery levels, link quality, mission states, telemetry recency, and details actions.
- **Service registry** with namespaces, TTL status, registration age, and health summaries.
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
flutter run -d chrome
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
```

## Project Layout

```text
lib/
  main.dart                  # App shell, theme, routing, responsive navigation
  pages/
    overview_page.dart       # System status, charts, heartbeats, event summary
    relays_page.dart         # Relay health and operational status
    agents_page.dart         # Agent fleet table and mission state
    registry_page.dart       # Service registry and TTL status
    nodes_page.dart          # Compute node health and utilization
    telemetry_page.dart      # Performance metrics and custom charts
    events_page.dart         # Events placeholder
    settings_page.dart       # Settings placeholder
  widgets/
    section_page.dart        # Shared placeholder page layout
```

## Roadmap

- Connect dashboard cards and tables to live Aero Arc APIs.
- Add event filtering, severity grouping, and timeline drill-downs.
- Add relay and agent detail pages.
- Add authentication and role-aware settings.
- Replace representative sample data with typed domain models and repositories.
- Add golden tests for responsive dashboard layouts.

## Repository Notes

Generated build output, local editor files, Flutter tool caches, and machine-specific platform files are ignored. Source, platform scaffolding, assets, tests, and `pubspec.lock` are tracked so the app can be reproduced consistently.
