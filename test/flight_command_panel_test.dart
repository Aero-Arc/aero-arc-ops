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
  testWidgets(
    'stalled reconciliation resumes polling and retries the same command',
    (tester) async {
      final stalled = Completer<http.Response>();
      final paths = <String>[];
      var reads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/completion')) {
            return http.Response('{}', 404);
          }
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

  testWidgets('stalled submission retries the original request identity', (
    tester,
  ) async {
    final stalled = Completer<http.Response>();
    final keys = <String?>[];
    final api = AeroArcApiClient(
      missionControlToken: 'test',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/completion')) {
          return http.Response('{}', 404);
        }
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

  for (final outcome in ['delayed', 'error', 'timeout']) {
    testWidgets('commands wait for known completion status: $outcome', (
      tester,
    ) async {
      final stalled = Completer<http.Response>();
      var recovered = false;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/completion')) {
            if (recovered) return http.Response('{}', 404);
            if (outcome == 'error') return http.Response('unavailable', 503);
            return stalled.future;
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
      OutlinedButton arm() => tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'ARM'),
      );
      expect(arm().onPressed, isNull);
      if (outcome == 'timeout') {
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();
        expect(arm().onPressed, isNull);
      }
      recovered = true;
      if (outcome == 'delayed') {
        stalled.complete(http.Response('{}', 404));
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(arm().onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'definitive rejection releases pending identity after history refresh',
    (tester) async {
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/completion')) {
            return http.Response('{}', 404);
          }
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
          if (request.url.path.endsWith('/completion')) {
            return http.Response('{}', 404);
          }
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
          if (request.url.path.endsWith('/completion')) {
            return http.Response('{}', 404);
          }
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

  for (final flightStatus in ['planned', 'canceled']) {
    testWidgets('canceled intent disables commands for $flightStatus flight', (
      tester,
    ) async {
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          return request.url.path.endsWith('/completion')
              ? http.Response('{}', 404)
              : http.Response('{"commands":[]}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(
                api: api,
                intentStatus: 'canceled',
                flight: FlightRecord(
                  id: 'flight-1',
                  aircraftId: 'aircraft-1',
                  intentId: 'intent-1',
                  intentVersion: 1,
                  status: flightStatus,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controls = tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(controls, isNotEmpty);
      expect(controls.every((button) => button.onPressed == null), isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('stalled finalization callback times out and retries', (
    tester,
  ) async {
    final stalled = Completer<void>();
    var callbacks = 0;
    final api = AeroArcApiClient(
      missionControlToken: 'test',
      httpClient: MockClient((request) async {
        return request.url.path.endsWith('/completion')
            ? http.Response(
                '{"event_id":"event","state":"complete","outcome":"mission_completed"}',
                200,
              )
            : http.Response('{"commands":[]}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(
              api: api,
              flight: flight,
              onFinalized: () {
                callbacks++;
                return callbacks == 1 ? stalled.future : Future<void>.value();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(callbacks, 1);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(find.textContaining('summary refresh will retry'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(callbacks, 2);
    stalled.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  for (final blockedPath in ['/commands', '/completion']) {
    testWidgets('status polling stays independent when $blockedPath hangs', (
      tester,
    ) async {
      final stalled = Completer<http.Response>();
      var historyReads = 0;
      var completionReads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'test',
        httpClient: MockClient((request) async {
          final completion = request.url.path.endsWith('/completion');
          if (completion) {
            completionReads++;
          } else {
            historyReads++;
          }
          if (request.url.path.endsWith(blockedPath)) return stalled.future;
          return completion
              ? http.Response('{}', 404)
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(blockedPath == '/commands' ? completionReads : historyReads, 2);
      expect(blockedPath == '/commands' ? historyReads : completionReads, 1);
      stalled.complete(
        blockedPath == '/commands'
            ? http.Response('{"commands":[]}', 200)
            : http.Response('{}', 404),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('reconcile response updates evidence before the next poll', (
    tester,
  ) async {
    final api = AeroArcApiClient(
      missionControlToken: 'trusted-session',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/completion')) {
          return http.Response('{}', 404);
        }
        if (request.url.path.endsWith('/reconcile')) {
          return http.Response(
            jsonEncode({
              ...command('applied'),
              'observation_state': 'observed',
            }),
            200,
          );
        }
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
    await tester.tap(find.textContaining('ARM').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reconcile existing command'));
    await tester.tap(find.text('Reconcile existing command'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Observation: observed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('completion refresh survives unavailable command history', (
    tester,
  ) async {
    var finalized = 0;
    final api = AeroArcApiClient(
      missionControlToken: 'trusted-session',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/completion')) {
          return http.Response(
            '{"event_id":"event","state":"complete","outcome":"mission_completed"}',
            200,
          );
        }
        return http.Response('unavailable', 503);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlightCommandPanel(
              api: api,
              flight: flight,
              onFinalized: () async {
                finalized++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(finalized, 1);
    expect(find.textContaining('Command history unavailable:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'in-flight history blocks confirmation until other console authority arrives',
    (tester) async {
      final stale = Completer<http.Response>();
      var reads = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'trusted-session',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/completion')) {
            return http.Response('{}', 404);
          }
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
    'completion evidence blocks controls until durable finalization',
    (tester) async {
      var finalized = false;
      var notifications = 0;
      final api = AeroArcApiClient(
        missionControlToken: 'trusted',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/completion')) {
            return http.Response(
              jsonEncode({
                'state': finalized ? 'complete' : 'retrying',
                'attempts': 2,
                'error': finalized ? '' : 'monitoring temporarily unavailable',
                'evidence': {
                  'outcome': 'ended_early',
                  'landed_at_unix_ns': 1700000000000000000,
                  'disarmed_at_unix_ns': 1700000001000000000,
                },
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'commands': []}), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FlightCommandPanel(
                api: api,
                flight: flight,
                onFinalized: () async {
                  notifications++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Flight outcome'), findsOneWidget);
      expect(find.textContaining('Cleanup will retry:'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ARM'))
            .onPressed,
        isNull,
      );
      finalized = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Complete'), findsWidgets);
      expect(notifications, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(notifications, 1);
      expect(find.textContaining('Cleanup will retry:'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
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
        if (request.url.path.endsWith('/completion')) {
          return http.Response('{}', 404);
        }
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
        if (request.url.path.endsWith('/completion')) {
          return http.Response('{}', 404);
        }
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
