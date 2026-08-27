import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/intent_workflow_page.dart';

void main() {
  testWidgets(
    'new intent starts with one route point at the aircraft position',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntentWorkflowPage(
              aircraftId: 'aircraft-1',
              renderTiles: false,
              initialVolumeCenter: LatLng(35.2, -97.2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 point(s)'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      expect(find.text('Creating new intent'), findsOneWidget);
      expect(find.text('Aircraft aircraft-1'), findsWidgets);
    },
  );

  testWidgets('initial intent shows assigned intent context', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            initialIntent: OperationalIntent.fromJson(
              _intentJson(status: 'accepted', name: 'Pipeline'),
            ),
            initialVolumes: [_volumeModel()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Modify Mission Intent'), findsOneWidget);
    expect(find.text('Modifying assigned intent'), findsOneWidget);
    expect(find.text('Pipeline v1 - Aircraft aircraft-1'), findsOneWidget);
  });

  testWidgets('accepted intent imports a WPL into an exactly bound flight', (
    WidgetTester tester,
  ) async {
    final requestedPaths = <String>[];
    Map<String, dynamic>? importBody;
    String? idempotencyKey;
    String? importAuthorization;
    final apiClient = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      missionControlToken: 'local-dev-token',
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/v1/aircraft/aircraft-1/flights') {
          return _jsonResponse({'flights': []});
        }
        if (request.url.path ==
            '/api/v1/operational-intents/intent-1/flights') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse({
            'id': body['id'],
            'aircraft_id': 'aircraft-1',
            'intent_id': 'intent-1',
            'intent_version': 1,
            'status': 'planned',
            'mission_type': 'mavlink',
          });
        }
        if (request.url.path.endsWith('/missions/import')) {
          importBody = jsonDecode(request.body) as Map<String, dynamic>;
          idempotencyKey = request.headers['idempotency-key'];
          importAuthorization = request.headers['authorization'];
          final segments = request.url.pathSegments;
          final flightID = segments[segments.indexOf('flights') + 1];
          return _jsonResponse({
            'mission': _missionJson(flightId: flightID),
            'replayed': false,
          });
        }
        if (request.url.path == '/api/v1/operational-intents/intent-1/modify') {
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted', version: 2),
            'volumes': [_volumeJson()],
            'supersedes_intent_id': 'intent-1',
            'supersedes_version': 1,
          });
        }
        if (request.url.path ==
            '/api/v1/operational-intents/intent-1/preflight/evaluate') {
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted', version: 2),
            'checks': [],
            'blocked': false,
          });
        }
        if (request.url.path ==
            '/api/v1/operational-intents/intent-1/deconfliction/check') {
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted', version: 2),
            'posture': 'clear',
            'findings': [],
          });
        }
        return http.Response('unexpected ${request.method}', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            apiClient: apiClient,
            initialIntent: OperationalIntent.fromJson(
              _intentJson(status: 'accepted'),
            ),
            initialVolumes: [_volumeModel()],
            selectMissionSource: () async => const MissionSourceSelection(
              name: 'inside.waypoints',
              source:
                  'QGC WPL 110\n'
                  '0\t1\t0\t16\t0\t0\t0\t0\t35.2\t-97.2\t120\t1\n'
                  '1\t0\t0\t16\t0\t0\t0\t0\t35.21\t-97.21\t120\t1\n',
            ),
          ),
        ),
      ),
    );

    final import = find.widgetWithText(FilledButton, 'Select & import WPL');
    await tester.ensureVisible(import);
    await tester.tap(import);
    await tester.pumpAndSettle();

    expect(requestedPaths.first, '/api/v1/aircraft/aircraft-1/flights');
    expect(requestedPaths[1], '/api/v1/operational-intents/intent-1/flights');
    expect(requestedPaths.last, endsWith('/missions/import'));
    expect(idempotencyKey, startsWith('ops-mission-import-'));
    expect(importAuthorization, 'Bearer local-dev-token');
    expect(importBody?['aircraft_id'], 'aircraft-1');
    expect(importBody?['intent_id'], 'intent-1');
    expect(importBody?['intent_version'], 1);
    expect(find.text('1 item(s) · v1'), findsOneWidget);
    expect(
      find.textContaining('aircraft deployment remains a separate'),
      findsOneWidget,
    );
    await _confirmDeployment(tester);
    expect(find.text('Deploy validated mission'), findsOneWidget);

    final saveAndCheck = find.widgetWithText(FilledButton, 'Save & check');
    await tester.ensureVisible(saveAndCheck);
    await tester.tap(saveAndCheck);
    await tester.pumpAndSettle();

    expect(find.text('No WPL selected'), findsOneWidget);
    expect(find.text('Not validated'), findsWidgets);
    expect(find.text('Deploy validated mission'), findsNothing);
    expect(find.text('intent-1 v2'), findsWidgets);
  });

  testWidgets(
    'deployment confirmation retains one key across an outcome-unknown retry',
    (WidgetTester tester) async {
      final harness = _MissionDeploymentHarness(
        deploymentStatuses: ['outcome_unknown', 'applied'],
      );
      await _pumpImportedMission(tester, harness.client);

      await _confirmDeployment(tester);
      expect(find.text('Deploy validated mission'), findsOneWidget);
      expect(find.textContaining('does not arm the aircraft'), findsOneWidget);

      await _tapVisible(tester, find.text('Deploy validated mission'));
      expect(find.text('Outcome Unknown'), findsWidgets);
      expect(find.text('Retry same deployment'), findsOneWidget);

      await _tapVisible(tester, find.text('Retry same deployment'));
      expect(harness.deploymentKeys, hasLength(2));
      expect(harness.deploymentKeys.first, isNotEmpty);
      expect(harness.deploymentKeys.toSet(), hasLength(1));
      expect(harness.deploymentBodies, everyElement(isEmpty));
      expect(
        harness.authorizationHeaders,
        everyElement('Bearer local-dev-token'),
      );
      expect(find.text('Applied'), findsWidgets);
      expect(find.text('Retry same deployment'), findsNothing);
      expect(find.text('Prepare new deployment attempt'), findsNothing);
    },
  );

  testWidgets(
    'terminal deployment failure requires a fresh confirmation and key',
    (WidgetTester tester) async {
      final harness = _MissionDeploymentHarness(
        deploymentStatuses: ['binding_mismatch', 'applied'],
      );
      await _pumpImportedMission(tester, harness.client);
      await _confirmDeployment(tester);
      await _tapVisible(tester, find.text('Deploy validated mission'));

      expect(find.text('Binding Mismatch'), findsWidgets);
      expect(find.text('Retry same deployment'), findsNothing);
      final prepare = find.text('Prepare new deployment attempt');
      expect(prepare, findsOneWidget);
      await _tapVisible(tester, prepare);

      expect(find.text('Deploy validated mission'), findsNothing);
      expect(find.text('Review & confirm deployment'), findsOneWidget);
      await _confirmDeployment(tester);
      await _tapVisible(tester, find.text('Deploy validated mission'));

      expect(harness.deploymentKeys, hasLength(2));
      expect(harness.deploymentKeys[0], isNot(harness.deploymentKeys[1]));
      expect(find.text('Applied'), findsWidgets);
    },
  );

  testWidgets('pending is refresh-only until its command window expires', (
    WidgetTester tester,
  ) async {
    final harness = _MissionDeploymentHarness(
      deploymentStatuses: ['pending'],
      refreshStatus: 'pending',
      refreshExpired: true,
    );
    await _pumpImportedMission(tester, harness.client);
    await _confirmDeployment(tester);
    await _tapVisible(tester, find.text('Deploy validated mission'));

    expect(find.text('Retry same deployment'), findsNothing);
    expect(find.text('Prepare new deployment attempt'), findsNothing);
    expect(find.text('Refresh durable status'), findsOneWidget);

    await _tapVisible(tester, find.text('Refresh durable status'));
    expect(find.textContaining('Expired · prepare'), findsOneWidget);
    expect(find.text('Retry same deployment'), findsNothing);
    expect(find.text('Prepare new deployment attempt'), findsOneWidget);
  });

  testWidgets(
    'expired outcome unknown preserves exact reconciliation and blocks a new attempt',
    (WidgetTester tester) async {
      final harness = _MissionDeploymentHarness(
        deploymentStatuses: ['outcome_unknown'],
        refreshStatus: 'outcome_unknown',
        refreshExpired: true,
      );
      await _pumpImportedMission(tester, harness.client);
      await _confirmDeployment(tester);
      await _tapVisible(tester, find.text('Deploy validated mission'));
      await _tapVisible(tester, find.text('Refresh durable status'));

      expect(find.text('Prepare new deployment attempt'), findsNothing);
      expect(find.text('Retry exact reconciliation'), findsOneWidget);
      expect(
        find.textContaining('outcome may remain unresolved'),
        findsOneWidget,
      );

      await _tapVisible(tester, find.text('Retry exact reconciliation'));
      expect(harness.deploymentKeys, hasLength(2));
      expect(harness.deploymentKeys.toSet(), hasLength(1));
    },
  );

  testWidgets('mismatched deployment response is rejected by the view', (
    WidgetTester tester,
  ) async {
    final harness = _MissionDeploymentHarness(
      deploymentStatuses: ['pending'],
      mismatchDeploymentBinding: true,
    );
    await _pumpImportedMission(tester, harness.client);
    await _confirmDeployment(tester);
    await _tapVisible(tester, find.text('Deploy validated mission'));

    expect(find.text('Needs attention'), findsOneWidget);
    expect(
      find.textContaining('response binding does not match'),
      findsOneWidget,
    );
    expect(find.text('Durable status'), findsNothing);
  });

  testWidgets('missing local token blocks mission import and deployment', (
    WidgetTester tester,
  ) async {
    var sourceSelected = false;
    final harness = _MissionDeploymentHarness(
      token: '',
      deploymentStatuses: ['pending'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            apiClient: harness.client,
            initialIntent: OperationalIntent.fromJson(
              _intentJson(status: 'accepted'),
            ),
            initialVolumes: [_volumeModel()],
            selectMissionSource: () async {
              sourceSelected = true;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Missing · set AERO_ARC_MISSION_DEPLOYMENT_TOKEN'),
      findsOneWidget,
    );
    expect(
      find.text('Blocked · set AERO_ARC_MISSION_DEPLOYMENT_TOKEN'),
      findsOneWidget,
    );
    final import = find.widgetWithText(FilledButton, 'Select & import WPL');
    expect(tester.widget<FilledButton>(import).onPressed, isNull);
    expect(sourceSelected, isFalse);
    final review = find.widgetWithText(
      OutlinedButton,
      'Review & confirm deployment',
    );
    expect(tester.widget<OutlinedButton>(review).onPressed, isNull);
    expect(harness.deploymentKeys, isEmpty);
  });

  testWidgets('blocked check keeps intent editable and reruns through modify', (
    WidgetTester tester,
  ) async {
    final requestedPaths = <String>[];
    Map<String, dynamic>? volumeRequest;
    final apiClient = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final path = request.url.path;
        if (path == '/api/v1/operational-intents') {
          return _jsonResponse(_intentJson(status: 'draft'));
        }
        if (path == '/api/v1/operational-intents/intent-1/volumes') {
          volumeRequest = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse(_volumeJson());
        }
        if (path == '/api/v1/operational-intents/intent-1/submit') {
          return _jsonResponse(_intentJson(status: 'submitted'));
        }
        if (path == '/api/v1/operational-intents/intent-1/modify') {
          return _jsonResponse({
            'intent': _intentJson(
              status: 'submitted',
              name: 'Adjusted Mission',
            ),
            'volumes': [_volumeJson()],
            'supersedes_intent_id': 'intent-1',
            'supersedes_version': 1,
          });
        }
        if (path == '/api/v1/operational-intents/intent-1/preflight/evaluate') {
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted'),
            'checks': [
              {
                'id': 'preflight-0',
                'intent_id': 'intent-1',
                'intent_version': 1,
                'aircraft_id': 'aircraft-1',
                'category': 'airspace',
                'source': 'fleet_registry',
                'status': 'blocked',
                'summary': 'aircraft is not active or accepted',
                'requirement_code': 'AIRCRAFT-STATUS',
                'blocking': true,
              },
              {
                'id': 'preflight-1',
                'intent_id': 'intent-1',
                'intent_version': 1,
                'aircraft_id': 'aircraft-1',
                'category': 'battery',
                'source': 'maintenance_control',
                'status': 'blocked',
                'summary': 'battery state of health is below 80',
                'requirement_code': 'BATTERY-SOH-80',
                'blocking': true,
              },
            ],
            'blocked': true,
          });
        }
        if (path ==
            '/api/v1/operational-intents/intent-1/deconfliction/check') {
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted'),
            'posture': 'conflict',
            'findings': const [],
          });
        }
        return http.Response('unexpected ${request.method} $path', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            apiClient: apiClient,
            initialVolumes: [_volumeModel()],
          ),
        ),
      ),
    );

    expect(find.text('Mission date'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('End time'), findsOneWidget);
    expect(find.text('Volume shape'), findsOneWidget);
    expect(find.text('Box'), findsWidgets);

    final saveAndCheck = find.widgetWithText(FilledButton, 'Save & check');
    expect(saveAndCheck, findsOneWidget);
    expect(tester.widget<FilledButton>(saveAndCheck).onPressed, isNotNull);
    await tester.ensureVisible(saveAndCheck);
    tester.widget<FilledButton>(saveAndCheck).onPressed!();
    await tester.pumpAndSettle();

    expect(
      requestedPaths,
      contains('/api/v1/operational-intents/intent-1/volumes'),
    );
    expect(volumeRequest?['geojson'], isA<String>());

    expect(
      find.text(
        'BATTERY-SOH-80: battery state of health is below 80 (+1 more)',
      ),
      findsOneWidget,
    );
    final activationBlockers = find.widgetWithText(
      TextButton,
      'BATTERY-SOH-80: battery state of health is below 80 (+1 more)',
    );
    expect(activationBlockers, findsOneWidget);
    tester.widget<TextButton>(activationBlockers).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Activation blockers'), findsOneWidget);
    expect(find.text('BATTERY-SOH-80'), findsOneWidget);
    expect(find.text('battery state of health is below 80'), findsOneWidget);
    expect(find.text('AIRCRAFT-STATUS'), findsOneWidget);
    expect(find.text('aircraft is not active or accepted'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final missionName = find.widgetWithText(TextFormField, 'Mission name');
    expect(tester.widget<TextFormField>(missionName).enabled, isTrue);

    await tester.enterText(missionName, 'Adjusted Mission');
    await tester.ensureVisible(saveAndCheck);
    tester.widget<FilledButton>(saveAndCheck).onPressed!();
    await tester.pumpAndSettle();

    expect(
      requestedPaths,
      contains('/api/v1/operational-intents/intent-1/modify'),
    );
  });

  testWidgets('created intent is reused when follow-up checks fail', (
    WidgetTester tester,
  ) async {
    var createCount = 0;
    var volumeCount = 0;
    var modifyCount = 0;
    final apiClient = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/operational-intents') {
          createCount += 1;
          return _jsonResponse(_intentJson(status: 'draft'));
        }
        if (path == '/api/v1/operational-intents/intent-1/volumes') {
          volumeCount += 1;
          return _jsonResponse(_volumeJson());
        }
        if (path == '/api/v1/operational-intents/intent-1/submit') {
          return _jsonResponse(_intentJson(status: 'submitted'));
        }
        if (path == '/api/v1/operational-intents/intent-1/modify') {
          modifyCount += 1;
          return _jsonResponse({
            'intent': _intentJson(status: 'submitted'),
            'volumes': [_volumeJson()],
            'supersedes_intent_id': 'intent-1',
            'supersedes_version': 1,
          });
        }
        if (path == '/api/v1/operational-intents/intent-1/preflight/evaluate') {
          return http.Response('preflight unavailable', 503);
        }
        return http.Response('unexpected ${request.method} $path', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            apiClient: apiClient,
            initialVolumes: [_volumeModel()],
          ),
        ),
      ),
    );

    final saveAndCheck = find.widgetWithText(FilledButton, 'Save & check');
    await tester.ensureVisible(saveAndCheck);
    tester.widget<FilledButton>(saveAndCheck).onPressed!();
    await tester.pumpAndSettle();

    expect(createCount, 1);
    expect(volumeCount, 1);
    expect(modifyCount, 0);

    await tester.ensureVisible(saveAndCheck);
    tester.widget<FilledButton>(saveAndCheck).onPressed!();
    await tester.pumpAndSettle();

    expect(createCount, 1);
    expect(volumeCount, 1);
    expect(modifyCount, 1);
  });

  testWidgets('volume width edits update the map preview immediately', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
            initialVolumes: [_volumeModel()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = _previewPolygon(tester);
    final widthField = find.widgetWithText(TextFormField, 'Box padding meters');
    await tester.ensureVisible(widthField);
    await tester.enterText(widthField, '300');
    await tester.pump();

    final after = _previewPolygon(tester);
    expect(after.first.latitude, lessThan(before.first.latitude));
    expect(after.first.longitude, lessThan(before.first.longitude));
  });

  testWidgets('workflow validation errors use a neutral title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: const Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
            renderTiles: false,
          ),
        ),
      ),
    );

    final saveAndCheck = find.widgetWithText(FilledButton, 'Save & check');
    await tester.ensureVisible(saveAndCheck);
    tester.widget<FilledButton>(saveAndCheck).onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('API unavailable'), findsNothing);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsNothing);
  });
}

Future<void> _pumpImportedMission(
  WidgetTester tester,
  AeroArcApiClient apiClient,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IntentWorkflowPage(
          aircraftId: 'aircraft-1',
          renderTiles: false,
          apiClient: apiClient,
          initialIntent: OperationalIntent.fromJson(
            _intentJson(status: 'accepted'),
          ),
          initialVolumes: [_volumeModel()],
          selectMissionSource: () async => const MissionSourceSelection(
            name: 'deployment.waypoints',
            source:
                'QGC WPL 110\n'
                '0\t1\t0\t16\t0\t0\t0\t0\t35.2\t-97.2\t120\t1\n'
                '1\t0\t0\t16\t0\t0\t0\t0\t35.21\t-97.21\t120\t1\n',
          ),
        ),
      ),
    ),
  );
  final import = find.widgetWithText(FilledButton, 'Select & import WPL');
  await _tapVisible(tester, import);
  expect(find.text('1 item(s) · v1'), findsOneWidget);
}

Future<void> _confirmDeployment(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Review & confirm deployment'));
  expect(find.text('Confirm mission deployment binding'), findsOneWidget);
  expect(find.textContaining('does not arm the aircraft'), findsWidgets);
  await tester.tap(find.text('Confirm exact binding'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _MissionDeploymentHarness {
  _MissionDeploymentHarness({
    this.token = 'local-dev-token',
    required this.deploymentStatuses,
    this.refreshStatus,
    this.refreshExpired = false,
    this.mismatchDeploymentBinding = false,
  }) {
    client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      missionControlToken: token,
      httpClient: MockClient(_handle),
    );
  }

  final String token;
  final List<String> deploymentStatuses;
  final String? refreshStatus;
  final bool refreshExpired;
  final bool mismatchDeploymentBinding;
  final List<String> deploymentKeys = [];
  final List<List<int>> deploymentBodies = [];
  final List<String?> authorizationHeaders = [];
  late final AeroArcApiClient client;
  int _deployCount = 0;

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    if (path == '/api/v1/aircraft/aircraft-1/flights') {
      return _jsonResponse({
        'flights': [
          {
            'id': 'flight-1',
            'aircraft_id': 'aircraft-1',
            'intent_id': 'intent-1',
            'intent_version': 1,
            'status': 'planned',
            'mission_type': 'mavlink',
          },
        ],
      });
    }
    if (path == '/api/v1/flights/flight-1/missions/import') {
      expect(request.headers['authorization'], 'Bearer local-dev-token');
      expect(request.headers['idempotency-key'], isNotEmpty);
      return _jsonResponse({'mission': _missionJson(), 'replayed': false});
    }
    if (path == '/api/v1/flights/flight-1/missions/mission-1/deploy') {
      deploymentKeys.add(request.headers['idempotency-key'] ?? '');
      deploymentBodies.add(request.bodyBytes);
      authorizationHeaders.add(request.headers['authorization']);
      expect(request.headers['if-match'], '"${List.filled(64, 'b').join()}"');
      final status =
          deploymentStatuses[_deployCount.clamp(
            0,
            deploymentStatuses.length - 1,
          )];
      _deployCount += 1;
      return _jsonResponse({
        'deployment': _deploymentJson(
          status: status,
          flightId: mismatchDeploymentBinding ? 'flight-other' : 'flight-1',
        ),
        'replayed': _deployCount > 1,
      });
    }
    if (path == '/api/v1/flights/flight-1/mission-deployments/deployment-1') {
      return _jsonResponse(
        _deploymentJson(
          status: refreshStatus ?? deploymentStatuses.last,
          expired: refreshExpired,
        ),
      );
    }
    return http.Response('unexpected ${request.method} $path', 404);
  }
}

List<LatLng> _previewPolygon(WidgetTester tester) {
  final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
  return layer.polygons.first.points;
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, Object?> _intentJson({
  required String status,
  String name = 'Mission aircraft-1',
  int version = 1,
}) {
  return {
    'id': 'intent-1',
    'aircraft_id': 'aircraft-1',
    'version': version,
    'name': name,
    'summary': 'Operational intent for aircraft-1',
    'use_case': 'inspection',
    'authorization_path': 'demo',
    'population_category': 'cat_1',
    'status': status,
    'conformance_required': true,
    'route_summary': 'Local operational volume',
    'planned_start_at': '2026-06-19T18:00:00Z',
    'planned_end_at': '2026-06-19T19:00:00Z',
    'min_altitude_ft_agl': 100,
    'max_altitude_ft_agl': 250,
  };
}

Map<String, Object?> _missionJson({String flightId = 'flight-1'}) {
  return {
    'id': 'mission-1',
    'version': 1,
    'flight_id': flightId,
    'aircraft_id': 'aircraft-1',
    'intent_id': 'intent-1',
    'intent_version': 1,
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
  };
}

Map<String, Object?> _deploymentJson({
  required String status,
  String flightId = 'flight-1',
  bool expired = false,
}) {
  return {
    'id': 'deployment-1',
    'operator_id': 'operator-1',
    'flight_id': flightId,
    'aircraft_id': 'aircraft-1',
    'intent_id': 'intent-1',
    'intent_version': 1,
    'mission_id': 'mission-1',
    'mission_version': 1,
    'mission_digest': List.filled(64, 'b').join(),
    'command_id': 'command-1',
    'status': status,
    'message': status,
    'uploaded_item_count': status == 'applied' ? 1 : 0,
    'onboard_mission_digest': status == 'applied'
        ? List.filled(64, 'b').join()
        : null,
    'mavlink_mission_ack_type': status == 'applied' ? 0 : null,
    'issued_at': '2026-08-26T12:00:00Z',
    'expires_at': expired ? '2000-01-01T00:00:00Z' : '2100-01-01T00:00:00Z',
    'completed_at': status == 'applied' ? '2026-08-26T12:00:02Z' : null,
    'attempt_count': 1,
    'created_at': '2026-08-26T12:00:00Z',
    'updated_at': '2026-08-26T12:00:01Z',
  };
}

Map<String, Object?> _volumeJson() {
  return {
    'id': 'volume-1',
    'intent_id': 'intent-1',
    'intent_version': 1,
    'sequence': 1,
    'geojson': jsonEncode({
      'type': 'Polygon',
      'coordinates': [
        [
          [-97.5200, 35.4670],
          [-97.5120, 35.4670],
          [-97.5120, 35.4730],
          [-97.5200, 35.4730],
          [-97.5200, 35.4670],
        ],
      ],
    }),
    'min_altitude_m': 30.48,
    'max_altitude_m': 76.2,
    'altitude_ref': 'agl',
    'buffer_meters': 15,
    'volume_type': 'loiter',
  };
}

OperationalVolume _volumeModel() {
  final json = _volumeJson();
  return OperationalVolume.fromJson(json.cast<String, dynamic>());
}
