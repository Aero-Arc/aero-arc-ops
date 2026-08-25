import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';

void main() {
  test(
    'getAircraftState calls state endpoint and parses relay fixture',
    () async {
      Uri? requestedUri;
      final fixture = File(
        'test/fixtures/live_aircraft_state.json',
      ).readAsStringSync();
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            fixture,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final state = await client.getAircraftState('aircraft-1');

      expect(requestedUri?.path, '/api/v1/aircraft/aircraft-1/state');
      expect(state.connection.relayId, 'relay-central-1');
      expect(state.telemetry.position?.frameId, 'agent-1:100');
      expect(state.telemetry.battery?.remainingPct, 76);
      expect(state.telemetry.vehicle?.armed, isTrue);
      expect(state.telemetry.gps?.satellitesVisible, 14);
    },
  );

  test('operations parses the batch live-aircraft contract', () async {
    Uri? requestedUri;
    final stateFixture = jsonDecode(
      File('test/fixtures/live_aircraft_state.json').readAsStringSync(),
    );
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'metrics': [],
            'operational_intents': [],
            'conformance': [],
            'live_aircraft': [stateFixture],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final dashboard = await client.operations();

    expect(requestedUri?.path, '/api/v1/operations');
    expect(dashboard.liveAircraft, hasLength(1));
    expect(
      dashboard.liveAircraft.single.telemetry.gps?.fixType,
      'gps_fix_type_3d_fix',
    );
  });

  test('getAircraftMapView calls map endpoint and parses response', () async {
    Uri? requestedUri;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          '''
          {
            "aircraft": {
              "id": "aircraft-1",
              "tail_number": "N100AA",
              "name": "Eagle 1",
              "model": "ArcRunner",
              "manufacturer": "Aero Arc",
              "status": "active",
              "acceptance_status": "accepted",
              "remote_id_status": "broadcasting"
            },
            "live_state_available": false,
            "replay_samples": [],
            "operational_volumes": [],
            "conformance_events": []
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final view = await client.getAircraftMapView('aircraft-1', limit: 250);

    expect(requestedUri?.path, '/api/v1/aircraft/aircraft-1/map');
    expect(requestedUri?.queryParameters['limit'], '250');
    expect(view.aircraft.id, 'aircraft-1');
  });

  test('evaluateTelemetry posts a sample and parses conformance', () async {
    http.Request? capturedRequest;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'intent': {
              'id': 'intent-1',
              'aircraft_id': 'aircraft-1',
              'version': 2,
              'name': 'Inspection',
              'summary': 'Active inspection',
              'authorization_path': 'demo',
              'population_category': 'cat_1',
              'status': 'active',
              'conformance_required': true,
            },
            'summary': {
              'id': 'conformance-intent-1',
              'intent_id': 'intent-1',
              'intent_version': 2,
              'aircraft_id': 'aircraft-1',
              'status': 'non_conforming',
              'score': 0,
              'alert_count': 1,
              'reportability_status': 'review',
              'updated_at': '2026-08-23T20:00:00Z',
            },
            'events': [
              {
                'id': 'event-1',
                'intent_id': 'intent-1',
                'intent_version': 2,
                'aircraft_id': 'aircraft-1',
                'severity': 'warning',
                'event_code': 'intent_exit',
                'message': 'outside active volume',
                'occurred_at': '2026-08-23T20:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.evaluateTelemetry(
      TelemetrySample(
        id: 'sample-1',
        aircraftId: 'aircraft-1',
        intentId: 'intent-1',
        flightId: 'flight-1',
        recordedAt: DateTime.parse('2026-08-23T20:00:00Z'),
        latitude: 35.5,
        longitude: -97.5,
        altitudeM: 120,
        velocityMps: 0,
        headingDeg: 0,
      ),
    );

    expect(capturedRequest?.method, 'POST');
    expect(capturedRequest?.url.path, '/api/v1/telemetry');
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['aircraft_id'], 'aircraft-1');
    expect(body['intent_id'], 'intent-1');
    expect(body['latitude'], 35.5);
    expect(body['longitude'], -97.5);
    expect(body['altitude_m'], 120);
    expect(body['recorded_at'], '2026-08-23T20:00:00.000Z');
    expect(result.intent.id, 'intent-1');
    expect(result.summary.status, 'non_conforming');
    expect(result.events.single.eventCode, 'intent_exit');
  });
}
