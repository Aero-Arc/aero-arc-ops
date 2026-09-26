# Flight controls

The existing intent/flight planning page displays durable flight controls once
an exact flight is bound. Mission upload continues through the existing reviewed
mission deployment panel. Other controls submit approved command types to API;
Ops never contacts Relay or sends arbitrary MAVLink parameters.

Confirmation creates an idempotency key retained for uncertain-response retry.
API history is restored on entry and polled while the panel is mounted. An
unresolved command blocks additional actions. Reconcile schedules evidence
recovery for the existing command rather than creating another action.

Application state and observation are shown separately. Expanded history displays
immutable source event time alongside API receipt time. PAUSE/RESUME may be
applied with observation unavailable; LAND may be applied while touchdown is
still pending. The existing local mission-control token gates these routes.

The panel uses the repository API client, DTO, shared dark Panel, and widget-test patterns.

Opening an existing intent restores its exact version's saved boundary and
mission waypoints beside the aircraft commands. Aircraft position and vehicle
state refresh independently of geometry, with the API's freshness and each
sample's timestamp. A telemetry outage retains the plan and labels the last
position unavailable; another intent version cannot replace the selected plan.

Controls are grouped into aircraft, mission, and recovery actions, with bounded
scrolling command history. Boundary editing is expandable, and planning, checks,
and deployment use responsive columns below the operational context.
