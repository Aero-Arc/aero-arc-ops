import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';

void main() {
  test('parses aircraft dashboard response with snake case fields', () {
    final parsed = AircraftListResponse.fromJson({
      'aircraft': [
        {
          'aircraft': {
            'id': 'aircraft-1',
            'agent_id': 'agent-1',
            'tail_number': 'N100AA',
            'name': 'Eagle 1',
            'model': 'ArcRunner',
            'manufacturer': 'Aero Arc',
            'status': 'active',
            'acceptance_status': 'accepted',
            'remote_id_status': 'broadcasting',
          },
          'active_battery': {
            'id': 'battery-1',
            'serial_number': 'B-1',
            'model': 'Pack',
            'state_of_health': 94,
            'cycle_count': 12,
            'status': 'current',
          },
          'maintenance_events': [],
          'latest_telemetry': {
            'id': 'sample-1',
            'aircraft_id': 'aircraft-1',
            'recorded_at': '2026-06-14T12:00:00Z',
            'latitude': 35.1,
            'longitude': -97.2,
            'altitude_m': 90,
            'velocity_mps': 12,
            'heading_deg': 180,
            'battery_pct': 87,
          },
          'live_state': {
            'aircraft_id': 'aircraft-1',
            'agent_id': 'agent-1',
            'relay_id': 'relay-1',
            'connected': true,
          },
          'live_state_available': true,
          'readiness': {'status': 'ready', 'reasons': []},
        },
      ],
    });

    expect(parsed.aircraft, hasLength(1));
    expect(parsed.aircraft.single.aircraft.displayName, 'Eagle 1');
    expect(parsed.aircraft.single.activeBattery?.stateOfHealth, 94);
    expect(parsed.aircraft.single.liveState?.relayId, 'relay-1');
    expect(parsed.aircraft.single.latestTelemetry?.batteryPct, 87);
  });

  test('parses overview dashboard collections', () {
    final parsed = OverviewDashboard.fromJson({
      'metrics': [
        {'label': 'Ready aircraft', 'value': '1/1', 'status': 'ready'},
      ],
      'aircraft': [],
      'operational_intents': [
        {
          'id': 'intent-1',
          'aircraft_id': 'aircraft-1',
          'name': 'Pipeline patrol',
          'summary': 'Inspect corridor',
          'authorization_path': 'permit',
          'population_category': 'cat_2',
          'status': 'accepted',
          'conformance_required': true,
          'planned_start_at': '2026-06-14T12:00:00Z',
          'planned_end_at': '2026-06-14T13:00:00Z',
        },
      ],
      'evidence_records': [],
      'reportability_reviews': [],
    });

    expect(parsed.metrics.single.label, 'Ready aircraft');
    expect(parsed.operationalIntents.single.conformanceRequired, isTrue);
    expect(parsed.operationalIntents.single.authorizationPath, 'permit');
  });
}
