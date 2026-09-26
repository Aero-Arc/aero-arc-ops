import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/pages/telemetry_page.dart';

void main() {
  testWidgets('slow identity enrichment does not delay conformance evidence', (
    tester,
  ) async {
    final names = Completer<http.Response>();
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/operations') return names.future;
        if (request.url.path == '/api/v1/conformance') {
          return _jsonResponse(
            _dashboardPayload(summaries: [_liveProjectionPayload()]),
          );
        }
        return http.Response('not found', 404);
      }),
    );
    await tester.pumpWidget(_testApp(client));
    await tester.pumpAndSettle();
    expect(find.text('aircraft-1 operation'), findsWidgets);
    names.complete(http.Response('unavailable', 503));
    await tester.pumpAndSettle();
    expect(find.text('aircraft-1 operation'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sample evaluation is hidden in normal builds', (tester) async {
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient(
        (_) async => _jsonResponse({
          'metrics': [
            {
              'label': 'Target conformance',
              'value': 'Not scored',
              'detail': 'Live condition is reported separately',
            },
          ],
          'summaries': [],
          'events': [],
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: TelemetryPage(apiClient: client)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evaluate API sample'), findsNothing);
    expect(
      find.text(
        'Target conformance: Not scored · Live condition is reported separately',
      ),
      findsOneWidget,
    );
  });

  testWidgets('conformance check posts telemetry and refreshes dashboard', (
    tester,
  ) async {
    var dashboardLoads = 0;
    Map<String, dynamic>? submitted;
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conformance') {
          dashboardLoads++;
          return _jsonResponse(_dashboardPayload());
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/telemetry') {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse(_evaluationPayload());
        }
        return http.Response('not found', 404);
      }),
    );

    await tester.pumpWidget(_testApp(client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Evaluate API sample'));
    await tester.pumpAndSettle();
    await _enterCheck(tester);
    await tester.tap(find.text('Evaluate sample'));
    await tester.pumpAndSettle();

    expect(submitted?['aircraft_id'], 'aircraft-1');
    expect(submitted?['intent_id'], 'intent-1');
    expect(submitted?['flight_id'], isNull);
    expect(submitted?['latitude'], 35.5);
    expect(submitted?['longitude'], -97.5);
    expect(submitted?['altitude_m'], 120);
    expect(submitted?['velocity_mps'], 0);
    expect(submitted?['heading_deg'], 0);
    expect(dashboardLoads, 2);
    expect(find.text('Latest Check Result'), findsOneWidget);
    expect(find.text('Non Conforming'), findsOneWidget);
    expect(find.text('1 new deviation event created.'), findsOneWidget);
  });

  testWidgets('failed conformance check preserves loaded dashboard', (
    tester,
  ) async {
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return _jsonResponse(
            _dashboardPayload(summaries: [_evaluationPayload()['summary']]),
          );
        }
        return http.Response('active operational intent not found', 404);
      }),
    );

    await tester.pumpWidget(_testApp(client));
    await tester.pumpAndSettle();
    expect(find.text('aircraft-1 operation'), findsWidgets);

    await tester.tap(find.text('Evaluate API sample'));
    await tester.pumpAndSettle();
    await _enterCheck(tester);
    await tester.tap(find.text('Evaluate sample'));
    await tester.pumpAndSettle();

    expect(find.text('Check failed'), findsOneWidget);
    expect(find.textContaining('API 404'), findsOneWidget);
    expect(find.text('aircraft-1 operation'), findsWidgets);
  });

  testWidgets('empty conformance view and check action fit narrow layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((_) async => _jsonResponse(_dashboardPayload())),
    );

    await tester.pumpWidget(_testApp(client));
    await tester.pumpAndSettle();

    expect(find.text('Evaluate API sample'), findsOneWidget);
    expect(
      find.text(
        'No monitored operations or conformance findings are available.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live Registry projection separates condition and pipeline state',
    (tester) async {
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient(
          (_) async => _jsonResponse(
            _dashboardPayload(summaries: [_liveProjectionPayload()]),
          ),
        ),
      );

      await tester.pumpWidget(_testApp(client));
      await tester.pumpAndSettle();

      expect(find.text('Conforming'), findsWidgets);
      expect(find.text('Current'), findsWidgets);
      expect(find.text('Confirmed'), findsWidgets);
      expect(
        find.descendant(of: find.byType(DataTable), matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tap(find.text('aircraft-1 operation').first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Evaluation at this observation'), findsOneWidget);
      expect(find.text('Lateral Deviation'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Evaluation evidence'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Evaluation evidence'));
      await tester.pumpAndSettle();
      expect(find.text('evaluation-7'), findsOneWidget);
    },
  );
}

Widget _testApp(AeroArcApiClient client) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: TelemetryPage(apiClient: client, enableSampleEvaluation: true),
    ),
  );
}

Future<void> _enterCheck(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Aircraft ID'),
    'aircraft-1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Intent ID (optional)'),
    'intent-1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Altitude (m AGL)'),
    '120',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Latitude'),
    '35.5',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Longitude'),
    '-97.5',
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _dashboardPayload({
  List<dynamic> summaries = const [],
  List<dynamic> events = const [],
}) {
  return {'metrics': [], 'summaries': summaries, 'events': events};
}

Map<String, dynamic> _evaluationPayload() {
  return {
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
  };
}

Map<String, dynamic> _liveProjectionPayload() {
  return {
    'id': 'assignment-intent-live',
    'intent_id': 'intent-live',
    'intent_version': 3,
    'flight_id': 'flight-live',
    'aircraft_id': 'aircraft-1',
    'status': 'conforming',
    'alert_count': 1,
    'reportability_status': '',
    'updated_at': '2026-08-23T20:00:00Z',
    'assignment_id': 'intent-live',
    'assignment_generation': 2,
    'evaluation_revision': 7,
    'evaluation_id': 'evaluation-7',
    'condition': 'conforming',
    'monitoring_status': 'current',
    'recording_status': 'confirmed',
    'observed_at': '2026-08-23T20:00:00Z',
    'frame_id': 'frame-42',
    'violations': [
      {
        'violation_type': 'lateral_deviation',
        'phase': 'suspected',
        'opening_frame_id': 'frame-40',
        'opened_at': '2026-08-23T19:59:58Z',
        'last_observed_at': '2026-08-23T20:00:00Z',
        'worst_deviation_m': 12.4,
      },
    ],
  };
}
