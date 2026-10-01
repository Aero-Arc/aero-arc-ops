# Durable mission demo candidate

Scope: authenticated durable commands, telemetry evidence, RTL or LAND recovery,
automatic flight finalization, Conformance closure, and API archival obligation.
The archive worker is a standalone foundation: no snapshot producer, archive
publication/discovery or Ops playback is claimed by this candidate.

## Upgrade boundary

API #42 to #43 is a coordinated upgrade, not a rolling-safe schema migration.
Disable command issuance, inventory unresolved commands and pending completions,
back up PostgreSQL plus Agent WAL and Relay completion SQLite files, and stop all
old API admission processes and dispatch workers before starting the new API.
Old workers do not set dispatch_started; running them alongside finalization can
misclassify an in-flight effect. An additive column does not make this safe.
Rehearse startup against an isolated restored database first. Retain all durable
stores on rollback; disable producers and prefer a compatible forward fix.
Never clear journals, reset idempotency identities or discard uncertain commands.

Deploy compatible Relay, Agent and Conformance before API and Ops. Require stable
Relay identity, authenticated control, persistent completion_outbox_path and Agent
wal-path, and explicit mission_rtl_v1 capability for RTL missions. SQLite URI paths
are not accepted as completion outbox paths. Local disk durability is not HA.

## Rehearsal

Use one recorded set of component commit SHAs, with clean worktrees. Run the
fixture harness against the API candidate, including populated/repeated reset.
Run the same authenticated public command workflow for UI and shell helpers:

1. Start the isolated observer stack and verify mission deployment.
2. Submit ARM and require observed armed state, then submit MISSION_START.
3. Verify independent telemetry for airborne, recovery, landed and disarmed.
4. Wait for API completion, Conformance closure and Agent context cleanup.
5. Refresh/reopen Ops and verify physical completion separately from a canceled
   planning intent. Repeat with terminal LAND and RTL.
6. Repeat response-loss and stream-replacement tests using the original command
   identity; restart services with retained stores. Never infer application from
   HTTP 202 or a Relay receipt.

The simulator helpers keep one command identity per flight/type. Another flight
requires a new flight ID, not silently regenerated command keys. `sitl-complete`
polls evidence; it neither forces completion nor clears Agent context itself.
Autopilot completion is bound to endpoint, system/component IDs and vehicle
profile. A changed binding fails closed; MAVLink IDs are not authenticated
hardware identities. The configured UDP listener remains stable across peer-port
changes; changing the configured endpoint requires explicit recovery.

A parallel rehearsal can select AERO_ARC_SITL_PORT_OFFSET (0..9000), a distinct
AERO_ARC_SITL_INSTANCE, AERO_ARC_SITL_COMPOSE_PROJECT, AERO_ARC_SITL_TMUX_SESSION,
AERO_ARC_SITL_RUN_DIR, AERO_ARC_SITL_INFLUX_PORT and
AERO_ARC_SITL_CONFORMANCE_DB_PORT. All must identify test-owned resources. Set
AERO_ARC_SITL_ENDING_BEHAVIOR to rtl (default) or land. Keep the normal demo running
untouched. Candidate evidence must distinguish component tests, full-stack tests,
and real cloud/hardware validation.

## Recorded validation — October 1, 2026

The isolated terminal-LAND rehearsal completed with these source revisions:

| Component | Revision |
| --- | --- |
| API | 8714701fc1a079f4e2874271c982d4351e05f3b6 |
| Relay | dc07307ced5f18d53b28984d59aef0f30ce13f51 |
| Agent | 494bc3566709dedf28e190d711d09c50d2e05ced |
| Registry | b72e02cefe1772d750e034dae0f58165de8b3894 |
| Conformance | bc222e75cf05d5710ba4df65592e6375f368b023 |
| Ops | 124e95178dcd8a496eb35162c06093dd514eee1e |

All tracked component trees were clean when the runner recorded its manifest.
The manifest also records binary SHA-256 values. Subsequent UI-only review fixes
are covered by widget tests and builds; this table identifies the actual flight.

ARM and MISSION_START were both applied and observed. Agent was restarted after
airborne telemetry, preserving its WAL. The flight then landed, disarmed, and
completed with event 4468a154-cc0d-54fc-bf7c-17d97b71eed8 and outcome
mission_completed. Monitoring closure and Agent-context cleanup completed.

After completion, Relay and API were restarted with retained stores. Exact ARM
and MISSION_START resubmission preserved command IDs, digests, states, attempt
counts, and completion evidence. Nine deterministic federation scenarios also
passed against API 8714701 with seed 20261001; none were skipped.

Local artifacts are retained under
/tmp/aero-arc-sitl-readiness-sep30-land4/ (component manifest and service logs),
/tmp/readiness-land4-*.json, /tmp/readiness-land4-*.log,
/tmp/readiness-land4-*.sql, and /tmp/readiness-harness-artifacts30/.
These are local validation artifacts, not an uploaded archive or cloud evidence
bundle. The isolated stack was stopped after collection; the normal demo was
not restarted.

An earlier fresh simulator run rejected START with
"Mode change to AUTO failed: requires position". The runner now waits, with a
bounded timeout, for the current boot's EKF GPS-fusion announcement and fresh
position/GPS telemetry before submitting ARM or START. It does not bypass an
autopilot rejection or generate a replacement command identity.
