# Conformance workspace

Live condition, monitoring freshness, and recording status remain separate API
fields. The records table exposes lateral, vertical and temporal evaluation
phases; missing or stale spatial evidence is not presented as healthy.

The deviation timeline reads the selected operation's persisted history from
`GET /api/v1/operational-intents/{intent_id}/conformance/events`. It does not derive
historical events by watching live status changes. Configure the API's Conformance
gRPC connection and deploy the new history RPC before expecting recorded rows.
The local SITL runner configures this mTLS connection automatically on its next
startup. Do not restart an active demo merely to deploy this PR; `sitl-up` resets
the demo runtime and data. Existing deployments need an intentional service rollout.

- Select an operation, all/current generation, and an event-time window.
- The first page refreshes every three seconds; only the selected operation is read.
- Loading older pages pauses automatic history refresh to keep browsing stable.
  Refresh explicitly to return to the newest page.
- Click a transition for incident/frame/revision evidence and the aircraft map.
- A service error is **History unavailable**, never a healthy/empty timeline.
  Previously loaded records remain visible after a transient failure.
- Spatial zero is a measured zero; absent distances are not fabricated. Temporal
  cards use optional planned start/end bounds from the event's immutable assignment
  generation, not the current intent. They show time before planned start or past
  planned end at observation time. These outer bounds can contain gaps: an event
  between them is not labeled overdue. Missing bounds remain explicitly unknown.
  Planned completion is not actual landing/completion; resolved events retain their
  observation-time context rather than starting a live overdue counter.
- Summary and event cards are centered. Evidence uses aligned, selectable values
  and full-value copy buttons; identifiers are never shortened in copied data.

Legacy API sample-evaluation events remain visible for legacy-only summaries.
The workspace does not change flight commands, conformance thresholds, or the
worker's incident lifecycle. Existing reportability and identity details remain
in the record inspector. The shared gRPC contract is internal: the browser still
speaks HTTP/JSON only.
