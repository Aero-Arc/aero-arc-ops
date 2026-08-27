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

  test('mission import sends exact binding and idempotency key', () async {
    http.Request? capturedRequest;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      missionControlToken: 'local-dev-token',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return _missionImportResponse();
      }),
    );

    final result = await client.importMission(
      flightId: 'flight-1',
      aircraftId: 'aircraft-1',
      intentId: 'intent-1',
      intentVersion: 4,
      source: 'QGC WPL 110\n',
      idempotencyKey: 'import-1',
    );

    expect(capturedRequest?.method, 'POST');
    expect(
      capturedRequest?.url.path,
      '/api/v1/flights/flight-1/missions/import',
    );
    expect(capturedRequest?.headers['idempotency-key'], 'import-1');
    expect(capturedRequest?.headers['authorization'], 'Bearer local-dev-token');
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['source_format'], 'qgc_wpl_110');
    expect(body['aircraft_id'], 'aircraft-1');
    expect(body['intent_id'], 'intent-1');
    expect(body['intent_version'], 4);
    expect(result.mission.flightId, 'flight-1');
    expect(result.mission.items.single.latitude, closeTo(35.2, 0.0000001));
  });

  test(
    'mission deploy sends bearer and idempotency headers with empty body',
    () async {
      http.Request? capturedRequest;
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        missionControlToken: 'local-dev-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'deployment': _missionDeploymentJson(status: 'outcome_unknown'),
              'replayed': true,
            }),
            202,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      final missionPayload =
          jsonDecode(_missionImportResponse().body) as Map<String, dynamic>;
      final mission = Mission.fromJson(
        missionPayload['mission'] as Map<String, dynamic>,
      );
      final result = await client.deployMission(
        mission: mission,
        idempotencyKey: 'deploy-stable-1',
      );

      expect(capturedRequest?.method, 'POST');
      expect(
        capturedRequest?.url.path,
        '/api/v1/flights/flight-1/missions/mission-1/deploy',
      );
      expect(capturedRequest?.bodyBytes, isEmpty);
      expect(
        capturedRequest?.headers['authorization'],
        'Bearer local-dev-token',
      );
      expect(capturedRequest?.headers['idempotency-key'], 'deploy-stable-1');
      expect(
        capturedRequest?.headers['if-match'],
        '"${List.filled(64, 'b').join()}"',
      );
      expect(result.replayed, isTrue);
      expect(result.deployment.status, 'outcome_unknown');
      expect(result.deployment.intentVersion, 4);
      expect(result.deployment.attemptCount, 2);
    },
  );

  test(
    'mission deployment status uses bearer and scoped durable path',
    () async {
      http.Request? capturedRequest;
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        missionControlToken: 'local-dev-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode(_missionDeploymentJson(status: 'applied')),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      final deployment = await client.getMissionDeployment(
        flightId: 'flight-1',
        deploymentId: 'deployment-1',
      );

      expect(capturedRequest?.method, 'GET');
      expect(
        capturedRequest?.url.path,
        '/api/v1/flights/flight-1/mission-deployments/deployment-1',
      );
      expect(
        capturedRequest?.headers['authorization'],
        'Bearer local-dev-token',
      );
      expect(deployment.missionId, 'mission-1');
      expect(deployment.uploadedItemCount, 1);
      expect(deployment.onboardMissionDigest, List.filled(64, 'b').join());
    },
  );

  test('mission deploy rejects a noncanonical digest before HTTP', () async {
    var requested = false;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      missionControlToken: 'local-dev-token',
      httpClient: MockClient((request) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    final payload =
        jsonDecode(_missionImportResponse().body) as Map<String, dynamic>;
    final missionJson = Map<String, dynamic>.from(
      payload['mission'] as Map<String, dynamic>,
    )..['mission_digest'] = List.filled(64, 'B').join();

    await expectLater(
      client.deployMission(
        mission: Mission.fromJson(missionJson),
        idempotencyKey: 'deploy-1',
      ),
      throwsA(
        isA<AeroArcApiException>().having(
          (error) => error.message,
          'message',
          contains('lowercase SHA-256'),
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test(
    'mission control fails locally when development token is missing',
    () async {
      var requested = false;
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        missionControlToken: '',
        httpClient: MockClient((request) async {
          requested = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.importMission(
          flightId: 'flight-1',
          aircraftId: 'aircraft-1',
          intentId: 'intent-1',
          intentVersion: 4,
          source: 'QGC WPL 110\n',
          idempotencyKey: 'import-1',
        ),
        throwsA(
          isA<AeroArcApiException>().having(
            (error) => error.message,
            'message',
            contains('local development credential'),
          ),
        ),
      );
      final missionPayload =
          jsonDecode(_missionImportResponse().body) as Map<String, dynamic>;
      await expectLater(
        client.deployMission(
          mission: Mission.fromJson(
            missionPayload['mission'] as Map<String, dynamic>,
          ),
          idempotencyKey: 'deploy-1',
        ),
        throwsA(
          isA<AeroArcApiException>().having(
            (error) => error.message,
            'message',
            contains('local development credential'),
          ),
        ),
      );
      expect(requested, isFalse);
    },
  );

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

http.Response _missionImportResponse() {
  return http.Response(
    jsonEncode({
      'mission': {
        'id': 'mission-1',
        'version': 1,
        'flight_id': 'flight-1',
        'aircraft_id': 'aircraft-1',
        'intent_id': 'intent-1',
        'intent_version': 4,
        'source_format': 'qgc_wpl_110',
        'source_sha256': List.filled(64, 'a').join(),
        'mission_digest': List.filled(64, 'b').join(),
        'validation_findings': [],
        'items': [
          {
            'sequence': 0,
            'current': false,
            'frame': 0,
            'command': 16,
            'param1': 0,
            'param2': 0,
            'param3': 0,
            'param4': 0,
            'latitude_e7': 352000000,
            'longitude_e7': -972000000,
            'altitude_m': 120,
            'autocontinue': true,
          },
        ],
        'created_at': '2026-08-26T12:00:00Z',
      },
      'replayed': false,
    }),
    201,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _missionDeploymentJson({required String status}) {
  final digest = List.filled(64, 'b').join();
  return {
    'id': 'deployment-1',
    'operator_id': 'operator-1',
    'flight_id': 'flight-1',
    'aircraft_id': 'aircraft-1',
    'intent_id': 'intent-1',
    'intent_version': 4,
    'mission_id': 'mission-1',
    'mission_version': 1,
    'mission_digest': digest,
    'command_id': 'command-1',
    'status': status,
    'message': status == 'outcome_unknown' ? 'result wait ended' : null,
    'uploaded_item_count': status == 'applied' ? 1 : 0,
    'onboard_mission_digest': status == 'applied' ? digest : null,
    'mavlink_mission_ack_type': status == 'applied' ? 0 : null,
    'issued_at': '2026-08-26T12:00:00Z',
    'expires_at': '2026-08-26T12:05:00Z',
    'completed_at': status == 'applied' ? '2026-08-26T12:00:05Z' : null,
    'attempt_count': 2,
    'created_at': '2026-08-26T12:00:00Z',
    'updated_at': '2026-08-26T12:00:05Z',
  };
}
