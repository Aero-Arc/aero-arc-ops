import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/widgets/flight_command_panel.dart';

const flight = FlightRecord(
  id: 'flight-1',
  aircraftId: 'aircraft-1',
  intentId: 'intent-1',
  intentVersion: 1,
  status: 'planned',
);
Map<String, dynamic> command(String state) => {
  'id': 'command-1',
  'type': 'ARM',
  'state': state,
  'observation_state': 'pending',
  'attempts': 1,
  'events': <dynamic>[],
};
void main() {
  testWidgets('unavailable history does not assert an empty durable history', (
    tester,
  ) async {
    final api = AeroArcApiClient(
      missionControlToken: 'test',
      httpClient: MockClient(
        (request) async => http.Response('unavailable', 503),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(api: api, flight: flight),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Command history unavailable:'), findsOneWidget);
    expect(find.text('No accepted commands for this flight.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'stalled reconciliation resumes polling and retries the same command',
    (tester) async {
      final stalled = Completer<http.Response>();
      final paths = <String>[];
      var reads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/reconcile')) {
            paths.add(request.url.path);
            return paths.length == 1
                ? stalled.future
                : http.Response(
                    jsonEncode({
                      ...command('applied'),
                      'observation_state': 'observed',
                    }),
                    200,
                  );
          }
          reads++;
          return http.Response(
            jsonEncode({
              'commands': [command('outcome_unknown')],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ARM ·').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reconcile existing command'));
      await tester.tap(find.text('Reconcile existing command'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Evidence recovery unavailable:'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(reads, greaterThan(1));
      await tester.ensureVisible(find.text('Reconcile existing command'));
      await tester.tap(find.text('Reconcile existing command'));
      await tester.pumpAndSettle();
      expect(paths.length, 2);
      expect(paths[0], paths[1]);
      expect(find.text('ARM · applied'), findsOneWidget);
      stalled.complete(http.Response(jsonEncode(command('rejected')), 200));
      await tester.pumpAndSettle();
      expect(find.text('ARM · applied'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('history progress clears a failed reconciliation message', (
    tester,
  ) async {
    var recovered = false;
    var historyFailed = false;
    final api = AeroArcApiClient(
      missionControlToken: 'test',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/completion')) {
          return http.Response('{}', 404);
        }
        if (request.url.path.endsWith('/reconcile')) {
          return http.Response('unavailable', 503);
        }
        if (historyFailed) return http.Response('history outage', 503);
        return http.Response(
          jsonEncode({
            'commands': [
              {
                ...command(recovered ? 'applied' : 'outcome_unknown'),
                'observation_state': recovered ? 'observed' : 'pending',
              },
            ],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(api: api, flight: flight),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ARM ·').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reconcile existing command'));
    await tester.tap(find.text('Reconcile existing command'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Evidence recovery unavailable:'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Evidence recovery unavailable:'),
      findsOneWidget,
    );
    historyFailed = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Command history unavailable:'), findsOneWidget);
    expect(
      find.textContaining('Evidence recovery unavailable:'),
      findsOneWidget,
    );
    historyFailed = false;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Command history unavailable:'), findsNothing);
    expect(
      find.textContaining('Evidence recovery unavailable:'),
      findsOneWidget,
    );
    recovered = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Evidence recovery unavailable:'), findsNothing);
    expect(find.text('ARM · applied'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stalled submission retries the original request identity', (
    tester,
  ) async {
    final stalled = Completer<http.Response>();
    final keys = <String?>[];
    final api = AeroArcApiClient(
      missionControlToken: 'test',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          keys.add(request.headers['idempotency-key']);
          return keys.length == 1
              ? stalled.future
              : http.Response(jsonEncode(command('accepted')), 202);
        }
        return http.Response('{"commands":[]}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(api: api, flight: flight),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'ARM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue command'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry same request'));
    await tester.pumpAndSettle();
    expect(keys.length, 2);
    expect(keys[0], isNotNull);
    expect(keys[0], keys[1]);
    expect(find.text('ARM · accepted'), findsOneWidget);
    stalled.complete(http.Response(jsonEncode(command('rejected')), 200));
    await tester.pumpAndSettle();
    expect(find.text('ARM · accepted'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'definitive rejection releases pending identity after history refresh',
    (tester) async {
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          return request.method == 'POST'
              ? http.Response('denied', 403)
              : http.Response('{"commands":[]}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'ARM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Issue command'));
      await tester.pumpAndSettle();
      expect(find.text('Retry same request'), findsNothing);
      expect(find.textContaining('Command rejected:'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'LAND'))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stalled history blocks confirmation then permits polling recovery',
    (tester) async {
      final stale = Completer<http.Response>();
      var reads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(jsonEncode(command('accepted')), 202);
          }
          reads++;
          if (reads == 2) return stale.future;
          return http.Response(
            jsonEncode({
              'commands': reads > 2 ? [command('applied')] : [],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'ARM'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.tap(find.text('Issue command'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('ARM · applied'), findsOneWidget);
      stale.complete(http.Response('{"commands":[]}', 200));
      await tester.pumpAndSettle();
      expect(find.text('ARM · applied'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'history blocker arriving during confirmation prevents submission',
    (tester) async {
      var blocked = false;
      var submissions = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            submissions++;
            return http.Response('{}', 500);
          }
          return http.Response(
            jsonEncode({
              'commands': blocked ? [command('acknowledged')] : [],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'ARM'));
      await tester.pumpAndSettle();
      blocked = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Issue command'));
      await tester.pumpAndSettle();
      expect(submissions, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'in-flight history blocks confirmation until other console authority arrives',
    (tester) async {
      final stale = Completer<http.Response>();
      var reads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'trusted-session',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            reads++;
            if (reads == 2) return stale.future;
            return http.Response('{"commands":[]}', 200);
          }
          return http.Response(jsonEncode(command('accepted')), 202);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ARM'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(reads, 2);
      await tester.tap(find.text('Issue command'));
      await tester.pumpAndSettle();
      expect(find.text('ARM · accepted'), findsNothing);
      stale.complete(
        http.Response(
          jsonEncode({
            'commands': [command('acknowledged')],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ARM · acknowledged'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'LAND'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'shows verification progress separately from recovery deliveries',
    (tester) async {
      final api = AeroArcApiClient(
        missionControlToken: 'trusted-session',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'commands': [
                {
                  ...command('acknowledged'),
                  'attempts': 3,
                  'events': [
                    {
                      'stage': 'verifying_mission',
                      'occurred_at': '2026-09-26T05:00:00Z',
                      'received_at': '2026-09-26T05:00:01Z',
                      'source': 'agent',
                      'message': 'Verifying onboard mission',
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(api: api, flight: flight),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ARM · Verifying onboard mission'), findsOneWidget);
      expect(
        find.textContaining('Initial delivery + 2 recovery deliveries'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('restores applied state without claiming observation', (
    tester,
  ) async {
    final api = AeroArcApiClient(
      missionControlToken: 'trusted-session',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer trusted-session');
        return http.Response(
          jsonEncode({
            'commands': [command('applied')],
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(api: api, flight: flight),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ARM · applied'), findsOneWidget);
    expect(find.textContaining('Observation: pending'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('lost response retries the same idempotency key', (tester) async {
    final keys = <String>[];
    final api = AeroArcApiClient(
      missionControlToken: 'trusted-session',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"commands":[]}', 200);
        }
        keys.add(request.headers['Idempotency-Key']!);
        expect(jsonDecode(request.body)['type'], 'ARM');
        if (keys.length == 1) throw http.ClientException('response lost');
        return http.Response(jsonEncode(command('accepted')), 202);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(api: api, flight: flight),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ARM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue command'));
    await tester.pumpAndSettle();
    expect(find.text('Retry same request'), findsOneWidget);
    await tester.tap(find.text('Retry same request'));
    await tester.pumpAndSettle();
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
    expect(find.text('ARM · accepted'), findsOneWidget);
    final land = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'LAND'),
    );
    expect(land.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
