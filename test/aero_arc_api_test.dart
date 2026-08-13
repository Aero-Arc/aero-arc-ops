import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';

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
}
