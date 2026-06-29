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

  testWidgets('volume width edits update the map preview immediately', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: IntentWorkflowPage(
            aircraftId: 'aircraft-1',
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
          body: IntentWorkflowPage(aircraftId: 'aircraft-1'),
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
}) {
  return {
    'id': 'intent-1',
    'aircraft_id': 'aircraft-1',
    'version': 1,
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
