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
hardware identities. UDP peer-port changes require explicit recovery rather than
silently transferring a flight watch.

A parallel rehearsal can select AERO_ARC_SITL_PORT_OFFSET (0..9000), a distinct
AERO_ARC_SITL_INSTANCE, AERO_ARC_SITL_COMPOSE_PROJECT, AERO_ARC_SITL_TMUX_SESSION,
AERO_ARC_SITL_RUN_DIR, AERO_ARC_SITL_INFLUX_PORT and
AERO_ARC_SITL_CONFORMANCE_DB_PORT. All must identify test-owned resources. Set
AERO_ARC_SITL_ENDING_BEHAVIOR to rtl (default) or land. Keep the normal demo running
untouched. Candidate evidence must distinguish component tests, full-stack tests,
and real cloud/hardware validation.
