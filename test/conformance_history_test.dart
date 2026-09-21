import 'dart:async';
import 'dart:convert';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/models/conformance_history.dart';
import 'package:aero_arc_web/widgets/conformance_history_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const summary = ConformanceSummary(
  id: 'live',
  intentId: 'intent',
  intentVersion: 2,
  aircraftId: 'AA-07',
  status: 'conforming',
  alertCount: 0,
  reportabilityStatus: 'no',
  assignmentId: 'intent',
  assignmentGeneration: 2,
  monitoringStatus: 'current',
);

Map<String, dynamic> event(
  String id, {
  String transition = 'opened',
  double? deviation,
}) => {
  'id': id,
  'assignment_id': 'intent',
  'assignment_generation': 2,
  'intent_id': 'intent',
  'intent_version': 2,
  'aircraft_id': 'AA-07',
  'flight_id': 'flight',
  'incident_id': 'incident',
  'transition': transition,
  'violation_type': 'lateral_deviation',
  'observed_at': '2026-09-21T01:02:03Z',
  'frame_id': 'frame',
  'evaluation_revision': 4,
  if (deviation != null) 'deviation_m': deviation,
};
http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);
Widget app(AeroArcApiClient client) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ConformanceHistoryPanel(api: client, summaries: const [summary]),
    ),
  ),
);

void main() {
  test(
    'history preserves absent versus measured zero and encodes filters',
    () async {
      expect(
        ConformanceHistoryEvent.fromJson(event('missing')).deviationM,
        isNull,
      );
      expect(
        ConformanceHistoryEvent.fromJson(
          event('zero', deviation: 0),
        ).deviationM,
        0,
      );
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient((r) async {
          expect(
            r.url.path,
            '/api/v1/operational-intents/intent/conformance/events',
          );
          expect(r.url.queryParameters['page_token'], 'a+b/c=');
          expect(r.url.queryParameters['generation'], '2');
          expect(r.url.queryParameters['from'], '2026-09-21T00:00:00.000Z');
          return jsonResponse({'events': []});
        }),
      );
      final page = await client.conformanceHistory(
        'intent',
        generation: 2,
        from: DateTime.utc(2026, 9, 21),
        pageToken: 'a+b/c=',
      );
      expect(page.events, isEmpty);
    },
  );

  testWidgets(
    'records show recovery, paginate, and pause polling while browsing',
    (tester) async {
      var calls = 0;
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient((r) async {
          calls++;
          if (r.url.queryParameters['page_token'] == 'older') {
            return jsonResponse({
              'events': [event('opened', deviation: 42)],
            });
          }
          return jsonResponse({
            'events': [event('resolved', transition: 'resolved', deviation: 0)],
            'next_page_token': 'older',
          });
        }),
      );
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      expect(find.text('Lateral Deviation · Resolved'), findsOneWidget);
      expect(find.textContaining('0.0 m at transition'), findsOneWidget);
      await tester.ensureVisible(find.text('Load older events'));
      await tester.tap(find.text('Load older events'));
      await tester.pumpAndSettle();
      expect(find.text('Lateral Deviation · Opened'), findsOneWidget);
      final afterPage = calls;
      await tester.pump(const Duration(seconds: 4));
      expect(calls, afterPage);
      await tester.tap(find.text('Lateral Deviation · Opened'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Event ID'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Event ID'), findsOneWidget);
      expect(find.text('opened'), findsOneWidget);
    },
  );

  testWidgets(
    'unavailable history is not empty or healthy and recovers on retry',
    (tester) async {
      var fail = true;
      final client = AeroArcApiClient(
        baseUri: Uri.parse('http://api.test'),
        httpClient: MockClient(
          (_) async => fail
              ? http.Response('{"error":"history unavailable"}', 503)
              : jsonResponse({'events': []}),
        ),
      );
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      expect(find.text('History unavailable'), findsOneWidget);
      expect(find.textContaining('No recorded transitions'), findsNothing);
      fail = false;
      await tester.tap(find.text('Retry history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No recorded transitions'), findsOneWidget);
      expect(find.text('History unavailable'), findsNothing);
    },
  );

  testWidgets('changing generation discards an older in-flight response', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    final generations = <String?>[];
    final client = AeroArcApiClient(
      baseUri: Uri.parse('http://api.test'),
      httpClient: MockClient((r) async {
        generations.add(r.url.queryParameters['generation']);
        if (generations.length == 1) return first.future;
        return jsonResponse({
          'events': [event('current', transition: 'resolved', deviation: 0)],
        });
      }),
    );
    await tester.pumpWidget(app(client));
    await tester.pump();
    await tester.tap(find.text('Current generation'));
    await tester.pumpAndSettle();
    first.complete(
      jsonResponse({
        'events': [event('old')],
      }),
    );
    await tester.pumpAndSettle();
    expect(generations, ['0', '2']);
    expect(find.text('Lateral Deviation · Resolved'), findsOneWidget);
    expect(find.text('Lateral Deviation · Opened'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('history filters fit a narrow workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = AeroArcApiClient(
      httpClient: MockClient(
        (_) async => jsonResponse({
          'events': [event('one', deviation: 12)],
        }),
      ),
    );
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('History time range'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last hour'));
    await tester.pumpAndSettle();
    expect(find.text('Last hour ▾'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
