import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';

void main() {
  test('parses independently timestamped live telemetry groups', () {
    final json =
        jsonDecode(
              File('test/fixtures/live_aircraft_state.json').readAsStringSync(),
            )
            as Map<String, dynamic>;

    final state = AircraftLiveState.fromJson(json);

    expect(state.aircraftId, 'aircraft-1');
    expect(state.connection.status, 'connected');
    expect(state.telemetry.status, 'fresh');
    expect(
      state.telemetry.position?.recordedAt,
      DateTime.parse('2026-08-11T12:00:30Z'),
    );
    expect(
      state.telemetry.battery?.recordedAt,
      DateTime.parse('2026-08-11T11:59:50Z'),
    );
    expect(state.telemetry.battery?.status, 'stale');
    expect(state.telemetry.system?.mainloopLoadPct, 43.2);
    expect(state.telemetry.hud?.climbRateMps, 0.2);
    expect(
      state.telemetry.extendedState?.landedState,
      'mav_landed_state_in_air',
    );
    expect(state.telemetry.vehicle?.armed, isTrue);
    expect(state.telemetry.gps?.fixType, 'gps_fix_type_3d_fix');
  });

  test('allows missing telemetry groups without inventing samples', () {
    final state = AircraftLiveState.fromJson({
      'aircraft_id': 'aircraft-2',
      'connection': {
        'aircraft_id': 'aircraft-2',
        'connected': false,
        'connection_status': 'unmapped',
      },
      'telemetry': {'status': 'missing'},
    });

    expect(state.connection.status, 'unmapped');
    expect(state.telemetry.status, 'missing');
    expect(state.telemetry.position, isNull);
    expect(state.telemetry.battery, isNull);
  });

  test('rejects present telemetry groups without required sample identity', () {
    expect(
      () => AircraftLiveState.fromJson({
        'aircraft_id': 'aircraft-2',
        'connection': {
          'aircraft_id': 'aircraft-2',
          'connected': true,
          'connection_status': 'connected',
        },
        'telemetry': {
          'status': 'fresh',
          'position': {
            'status': 'fresh',
            'latitude_deg': 29.7,
            'longitude_deg': -95.3,
          },
        },
      }),
      throwsFormatException,
    );
  });

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

  test('parses aircraft map view payload', () {
    final parsed = AircraftMapView.fromJson({
      'aircraft': {
        'id': 'aircraft-1',
        'tail_number': 'N100AA',
        'name': 'Eagle 1',
        'model': 'ArcRunner',
        'manufacturer': 'Aero Arc',
        'status': 'active',
        'acceptance_status': 'accepted',
        'remote_id_status': 'broadcasting',
      },
      'live_state': {
        'aircraft_id': 'aircraft-1',
        'agent_id': 'agent-1',
        'relay_id': 'relay-1',
        'connected': true,
      },
      'live_state_available': true,
      'latest_telemetry': {
        'id': 'sample-2',
        'aircraft_id': 'aircraft-1',
        'recorded_at': '2026-06-14T12:01:00Z',
        'latitude': 35.2,
        'longitude': -97.2,
        'altitude_m': 92,
        'velocity_mps': 12,
        'heading_deg': 180,
      },
      'replay_samples': [
        {
          'id': 'sample-1',
          'aircraft_id': 'aircraft-1',
          'recorded_at': '2026-06-14T12:00:00Z',
          'latitude': 35.1,
          'longitude': -97.1,
          'altitude_m': 90,
          'velocity_mps': 12,
          'heading_deg': 180,
        },
      ],
      'active_intent': {
        'id': 'intent-1',
        'aircraft_id': 'aircraft-1',
        'name': 'Pipeline patrol',
        'summary': 'Inspect corridor',
        'authorization_path': 'permit',
        'population_category': 'cat_2',
        'status': 'active',
        'conformance_required': true,
      },
      'operational_volumes': [
        {
          'id': 'volume-1',
          'intent_id': 'intent-1',
          'intent_version': 1,
          'sequence': 1,
          'geojson':
              '{"type":"Polygon","coordinates":[[[-98,35],[-97,35],[-97,36],[-98,36],[-98,35]]]}',
          'min_altitude_m': 10,
          'max_altitude_m': 120,
          'altitude_ref': 'agl',
        },
      ],
      'conformance_summary': {
        'id': 'summary-1',
        'intent_id': 'intent-1',
        'intent_version': 1,
        'aircraft_id': 'aircraft-1',
        'status': 'conforming',
        'alert_count': 1,
        'reportability_status': 'review',
      },
      'conformance_events': [
        {
          'id': 'event-1',
          'intent_id': 'intent-1',
          'intent_version': 1,
          'aircraft_id': 'aircraft-1',
          'severity': 'warning',
          'event_code': 'intent_exit',
          'message': 'outside volume',
          'latitude': 35.3,
          'longitude': -97.3,
        },
      ],
    });

    expect(parsed.aircraft.displayName, 'Eagle 1');
    expect(parsed.liveState?.relayId, 'relay-1');
    expect(parsed.latestTelemetry?.id, 'sample-2');
    expect(parsed.replaySamples, hasLength(1));
    expect(parsed.activeIntent?.id, 'intent-1');
    expect(parsed.operationalVolumes.single.id, 'volume-1');
    expect(parsed.conformanceSummary?.alertCount, 1);
    expect(parsed.conformanceEvents.single.eventCode, 'intent_exit');
  });
}
