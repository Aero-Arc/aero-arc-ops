import 'dart:async';
import 'dart:convert';

import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/models/conformance_history.dart';
import 'package:aero_arc_web/widgets/conformance_history_panel.dart';
import 'package:aero_arc_web/widgets/conformance_event_dialog.dart';
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
  'deviation_m': ?deviation,
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
  testWidgets('event dialog fits narrow screens and preserves evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final record = ConformanceHistoryEvent.fromJson({
      ...event('e' * 64, transition: 'resolved', deviation: 0),
      'frame_id': 'frame' * 40,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ConformanceEventDialog(event: record),
              ),
              child: const Text('Inspect'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();
    expect(find.text('0.0 m'), findsOneWidget);
    expect(find.text('Lateral Deviation · Resolved'), findsOneWidget);
    await tester.ensureVisible(find.text('Recorded evidence'));
    await tester.tap(find.text('Recorded evidence'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Evidence frame'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('frame' * 40), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byTooltip('Close event'),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byTooltip('Close event'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('event dialog preserves missing distance and map navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/aircraft/AA-07/map': (_) =>
              const Scaffold(body: Text('Aircraft map destination')),
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ConformanceEventDialog(
                  event: ConformanceHistoryEvent.fromJson(event('missing')),
                ),
              ),
              child: const Text('Inspect'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();
    expect(find.text('Distance not recorded'), findsOneWidget);
    expect(find.text('0.0 m'), findsNothing);
    await tester.ensureVisible(find.text('View aircraft map'));
    await tester.tap(find.text('View aircraft map'));
    await tester.pumpAndSettle();
    expect(find.text('Aircraft map destination'), findsOneWidget);
  });

  testWidgets(
    'generation refresh retains rows until replacement and ignores reselect',
    (tester) async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final client = AeroArcApiClient(
        httpClient: MockClient((_) async {
          calls++;
          if (calls == 1) {
            return jsonResponse({
              'events': [event('old')],
            });
          }
          return pending.future;
        }),
      );
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All generations'));
      await tester.pump();
      expect(calls, 1);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AA-07 · intent').last);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Lateral Deviation · Opened'), findsOneWidget);
      final before = tester.getRect(find.text('Lateral Deviation · Opened'));
      await tester.tap(find.text('Current generation'));
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Lateral Deviation · Opened'), findsOneWidget);
      expect(tester.getRect(find.text('Lateral Deviation · Opened')), before);
      expect(find.text('Loading recorded history…'), findsNothing);
      expect(
        find.text('Recorded incident transitions · newest first'),
        findsOneWidget,
      );
      pending.complete(
        jsonResponse({
          'events': [event('new', transition: 'resolved')],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lateral Deviation · Opened'), findsNothing);
      expect(find.text('Lateral Deviation · Resolved'), findsOneWidget);
      expect(find.textContaining('Previous filter results'), findsNothing);
    },
  );

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
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Lateral Deviation · Detected'), findsOneWidget);
      expect(find.text('42.0 m'), findsOneWidget);
      await tester.ensureVisible(find.text('Recorded evidence'));
      await tester.tap(find.text('Recorded evidence'));
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
      final message = tester.getRect(
        find.text(
          'Live monitoring may still be current. No history could be loaded.',
        ),
      );
      final retry = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Retry history'),
      );
      expect(retry.top - message.bottom, greaterThanOrEqualTo(12));
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
