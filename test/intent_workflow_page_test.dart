import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/pages/intent_workflow_page.dart';

void main() {
  testWidgets('blocked check keeps intent editable and reruns through modify', (
    WidgetTester tester,
  ) async {
    final requestedPaths = <String>[];
    final apiClient = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        requestedPaths.add(request.url.path);
        final path = request.url.path;
        if (path == '/api/v1/operational-intents') {
          return _jsonResponse(_intentJson(status: 'draft'));
        }
        if (path == '/api/v1/operational-intents/intent-1/volumes') {
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
            'checks': const [],
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
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save & check'));
    await tester.pumpAndSettle();

    final missionName = find.widgetWithText(TextFormField, 'Mission name');
    expect(tester.widget<TextFormField>(missionName).enabled, isTrue);

    await tester.enterText(missionName, 'Adjusted Mission');
    await tester.tap(find.text('Save & check'));
    await tester.pumpAndSettle();

    expect(
      requestedPaths,
      contains('/api/v1/operational-intents/intent-1/modify'),
    );
  });
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
