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
- **Live conformance view** with assignment condition, monitoring freshness,
  recording durability, active findings, evaluated axes, and evaluation/frame
  provenance read from Registry through the API.
- **Aircraft map** that combines replay, authorized operational volumes, an
  intent-bound validated mission plan, conformance evidence, and a one-second live
  tracker. Violet authorization, cyan mission waypoints, green observed flight,
  and the amber ten-second motion projection remain separate map layers.
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

For WSL or another environment where Flutter cannot launch Chrome directly,
start the web server and open `http://localhost:7357` in your browser:

```sh
make web
```

Override the defaults when needed, for example:

```sh
make web WEB_PORT=8081 API_BASE_URL=http://localhost:8080
```

Mission deployment additionally requires a local development credential:

```sh
make web MISSION_DEPLOY_TOKEN=replace-with-a-local-token-at-least-24-bytes
```

That value is compiled into the web application and is therefore only a local
development bridge. It must not be used as production operator authentication;
production deployment controls require user-scoped API sessions.

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

## Live conformance data contract

Operations and Conformance consume the API's Registry-backed projections. The
condition (`conforming`, `suspected`, or `non_conforming`), monitoring status,
and recording status are separate signals and are displayed independently. A
clear evaluated axis is evidence that a check ran; it is not an active finding.
The client does not invent freshness or conformance thresholds.

The Conformance page refreshes the batch dashboard every three seconds. Its
`Evaluate API sample` action is an explicit legacy/single-sample diagnostic;
normal live results are produced by Agent telemetry flowing through Relay,
Conformance, and Registry. Missing optional live fields degrade locally without
hiding durable conformance history.

An active intent that requires conformance but has no live summary is marked
unavailable and remains in both Needs Attention and Conformance alerts. A
missing summary or a legacy historical summary without assignment identity,
monitoring, recording, and watermark evidence cannot establish conformance.
The map's embedded conformance snapshot is only an initial-load and first-error
fallback. Once a live dashboard response succeeds, its presence or absence is
authoritative for that aircraft, intent, and version; later polling errors
retain that last live result and never resurrect an embedded summary that the
live dashboard omitted. A newly refreshed intent may use its own embedded
snapshot if its first live request fails.
Historical-only dashboard results count as live absence and cannot re-admit an
older embedded live projection. An embedded live projection is merged only
while the successful dashboard still contains that exact assignment ID and
generation. Cached live absence is scoped to the same assignment, so a newly
refreshed assignment can still use its embedded snapshot if its first live
request fails.

Within one intent version, live summaries are ordered first by assignment
generation and only then by that generation's evaluation revision. The
evaluation event time and frame/WAL cursor remain visible as provenance. A
missing lateral or altitude phase is shown as not evaluated at the summary
watermark. Every spatial phase, including `clear`, must carry a
`last_observed_at` at or after that watermark. Older retained incidents remain
visible, but are labeled not evaluated for the newer watermark; Ops never
invents current conformance or a clear recovery from an evidence gap.

The diagnostic action is hidden in normal builds. Enable it only for a local
diagnostic session with
`--dart-define=AERO_ARC_ENABLE_SAMPLE_CONFORMANCE=true`; submitted samples are
persisted and can create conformance findings.

## No-seed SITL observer stack

The repository includes a local WSL-oriented runner for watching one real
ArduCopter SITL instance through the full observation path. It builds sibling
Aero Arc repositories, starts isolated PostGIS and InfluxDB containers, starts
Registry, Relay, Conformance, API, Agent, Ops, and SITL, and then creates the
aircraft, battery installation, intent, volume, and flight through API routes.
API and Conformance use separate logical databases in the same PostGIS
instance, so their migrations remain isolated while API mission and flight
state exercises the durable PostgreSQL implementation. It does not load
fixture or seed data.

Prerequisites are Docker Compose, Flutter, Go, OpenSSL, tmux, and an existing
ArduPilot checkout with a built `ArduCopter` SITL binary. With the Aero Arc
repositories and `ardupilot` checked out beside this repository, run:

```sh
make sitl-up
make sitl-status
```

Open `http://localhost:7357`. `sitl-up` activates a ten-minute plan and gives
Conformance a separate 24-hour monitoring authority. Crossing the planned end
therefore produces an overdue temporal-deviation state; it does not silently
stop monitoring or mark the flight complete. Override these windows with
`AERO_ARC_SITL_PLAN_MINUTES` and `AERO_ARC_SITL_MONITOR_HOURS`.

The runner asks MAVProxy for a conservative 4 Hz SITL stream so the local demo
does not overwhelm a development Agent WAL with simulator telemetry. Override
it with `AERO_ARC_SITL_STREAM_RATE_HZ`, which must be a whole number from 1
through 50. For example, `AERO_ARC_SITL_STREAM_RATE_HZ=8 make sitl-up` requests
8 Hz. This is test-harness load control, not a substitute for production Agent
ingest throughput, batching, backpressure, and durable recovery.

`sitl-up` imports the checked-in WPL 110 demonstration mission and validates
every waypoint and complete route segment against the exact intent version. It
then asks only the API to deploy the current immutable mission. The API derives
the aircraft's Agent assignment, resolves that Agent's current Relay through
Registry, establishes the exact operation context, and sends the command over
mTLS. Neither Ops nor the observer chooses an Agent or Relay or resubmits
mission bytes. The Agent reports success only after an onboard readback matches
the API mission digest. Reconcile or retry the same durable command with:

```sh
make sitl-mission-deploy
```

The observer retains the API deployment ID. If the first request is pending,
temporarily unavailable, or outcome-unknown, startup and the manual command
POST an empty body to that deployment's reconciliation route; they never replay
the mission payload or create a replacement deployment.

Ops presents mission validation and durable aircraft-deployment status as
separate steps. The map also keeps the authorization, validated plan, and
observed flight visually separate. Start the AUTO mission with:

```sh
make sitl-mission-run
```

Reopening an accepted or active intent restores its exactly bound flight,
current immutable mission, and current durable deployment from the API. Ops
does not persist mission bytes, routing, command IDs, or deployment
idempotency keys in browser state. A non-404 restore failure blocks intent
changes as well as mission controls until an explicit durable-state retry
succeeds, because the failed lookup may conceal an unresolved aircraft effect.
An accepted or active workflow with a bound mission also remains blocked when
the local deployment credential is absent, because Ops cannot authenticate a
claim that no durable command exists.
Refreshes read the deployment by its durable ID, and retryable results use the
empty-body reconciliation route so the API reuses its server-owned command and
binding. An unexpired `pending` result is reconciled through that exact durable
identity; it is never resubmitted as a new deployment. An `already_applied`
result may be
readback-only with zero uploaded items; its exact onboard digest is the success
evidence. An `outcome_unknown` result remains visibly unresolved after its
reconciliation window closes and must never be treated as permission for a
replacement effect. Importing and validating a newer immutable mission does not
discard that durable blocker: Ops retains the prior deployment ID for refresh
and enables confirmation of the new mission only after the prior outcome is
resolved. Upload counts for a retained prior deployment are labeled with that
deployment's mission identity and never use the newer plan as their denominator.
Once another mission is current, Ops never automatically reconciles
the superseded mission because that could request an old replacement upload; it
permits exact-ID status refresh only and directs unresolved cases to manual
resolution. The same blocker is restored after a reload when the API returns
its complete durable identity for the exact flight and intent context, even
though the flight's current immutable mission is now newer. Context-matched
terminal history for an earlier mission version is ignored so it cannot poison
deployment of the newer current mission. An expired prior pending or temporary
attempt counts as terminal only when the API provides positive `expires_at`
evidence; a missing expiry remains unresolved and refresh-only. Unrelated or
malformed history still fails restoration closed.

An unresolved deployment on a non-planned flight also blocks switching to a
replacement planned flight or importing a replacement mission. Ops preserves
the original flight, mission, and durable deployment identity for exact status
refresh until the command reaches a terminal outcome.

The same unresolved-deployment fence blocks operational-intent modification;
an accepted intent cannot advance to a new version while an earlier aircraft
effect remains uncertain. When a version change is accepted by the API, Ops
atomically clears superseded acceptance/activation state before follow-up
checks, so a failed check cannot re-enable mission controls for the old version.

Returning to the aircraft map from an intent workflow reloads the full map read
model, including the commanded mission, active intent, volumes, history, and
embedded conformance evidence. Live-state polling remains independently aged.

Mission import is deliberately constrained to a single MSL Polygon volume and
the supported WPL 110 navigation commands. A mission cannot replace or reshape
the operational intent. `sitl-mission-run` configures SITL-only AUTO behavior,
selects AUTO in MAVProxy, waits until fresh API telemetry confirms that mode,
and sends ARM through the authenticated Relay/Agent command lifecycle. The
checked-in observer mission deliberately ends at an airborne waypoint rather
than LAND so the post-mission boundary checks remain possible; landing stays an
explicit operator action. The command plane also supports explicit ARM and
DISARM:

```sh
make sitl-arm
make sitl-disarm
```

Movement commands are still issued from MAVProxy. Start a takeoff and waypoint
demonstration, or attach to the interactive console:

```sh
make sitl-demo-flight
make sitl-console
```

While airborne, the repeatable post-window spatial check sends the aircraft
outside and then just back inside the authorized Polygon. This demonstrates
that lateral deviation can open and clear independently while the temporal
deviation remains open. These helpers wait for fresh armed/airborne telemetry
and API-confirmed GUIDED mode before sending a target, so calling them
immediately after `sitl-mission-run` is safe:

```sh
make sitl-out-of-bounds
make sitl-return-in-bounds
```

Land first, observe the landing/disarm, and only then complete the operational
lifecycle:

```sh
make sitl-land
make sitl-complete
make sitl-down
```

`sitl-complete` is deliberately explicit: it completes the API intent and
clears the matching Agent context, while the flight remains active if no
authoritative flight-completion signal has been implemented. Automatic
Agent-driven flight completion and broader guided movement commands remain
command-lifecycle work, not behavior simulated by this runner.

Source checkouts can be selected without editing the script, for example
`AERO_ARC_RELAY_SOURCE=/tmp/aero-arc-relay-mission make sitl-up`. The runner
fails before starting services when the selected Relay does not implement the
mission-deployment RPC. Its isolated Influx listener defaults to port `28181`
and can be changed with `AERO_ARC_SITL_INFLUX_PORT`. Runtime binaries,
certificates, WAL, logs, and PID files live under
`/tmp/aero-arc-sitl-observer` by default. If startup fails after resources are
created, the failure trap tears down child process groups, the tmux simulator,
and the isolated Compose stack before returning the startup error.

## Roadmap

- Add authenticated API sessions and role-aware controls.
- Add event filtering, severity grouping, and timeline drill-downs.
- Add relay and agent detail pages backed by registry read endpoints.
- Add golden tests for responsive dashboard layouts.

## Repository Notes

Generated build output, local editor files, Flutter tool caches, and machine-specific platform files are ignored. Source, platform scaffolding, assets, tests, and `pubspec.lock` are tracked so the app can be reproduced consistently.
