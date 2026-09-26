import 'dart:convert';
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
