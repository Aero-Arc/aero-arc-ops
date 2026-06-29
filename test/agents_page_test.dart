import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/agents_page.dart';

void main() {
  testWidgets('aircraft table shows current intent or none', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: AgentsPage(load: () async => sampleAircraftList()),
        ),
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('route:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v3'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byTooltip('Open aircraft map'), findsNWidgets(2));
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Needs Attention'), findsOneWidget);
    expect(find.text('Readiness Reasons'), findsNothing);
    expect(find.text('Hawk 2: Remote ID offline'), findsOneWidget);
    expect(find.text('Position'), findsNothing);
    expect(find.text('Latitude'), findsNothing);
    expect(find.text('Longitude'), findsNothing);
    expect(find.text('41.87810, -87.62980'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('All checks clear'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Remote ID offline, Open maintenance hold'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Ready\nNo readiness blockers'), findsOneWidget);
    expect(
      find.byTooltip('Blocked\n- Remote ID offline\n- Open maintenance hold'),
      findsOneWidget,
    );
    expect(find.text('Acceptance'), findsNothing);
    expect(find.text('active'), findsNothing);

    await tester.tap(find.byTooltip('Open aircraft map').first);
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/map'), findsOneWidget);

    Navigator.of(
      tester.element(find.text('route:/aircraft/aircraft-1/map')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();

    expect(find.text('Eagle 1'), findsNothing);
    expect(find.text('Hawk 2'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip('Blocked\n- Remote ID offline\n- Open maintenance hold'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hawk 2 readiness'), findsOneWidget);
    expect(find.text('Dispatch Posture'), findsOneWidget);
    expect(find.text('Remote ID'), findsAtLeastNWidgets(1));
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Telemetry'), findsOneWidget);
    expect(find.text('Live state unavailable'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final intentButton = find.widgetWithText(TextButton, 'Pipeline v3');
    await tester.ensureVisible(intentButton);
    await tester.tap(intentButton);
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/intent/new'), findsOneWidget);
  });
}

AircraftListResponse sampleAircraftList() {
  return const AircraftListResponse(
    aircraft: [
      AircraftDashboard(
        aircraft: Aircraft(
          id: 'aircraft-1',
          tailNumber: 'N100AA',
          name: 'Eagle 1',
          model: 'ArcRunner',
          manufacturer: 'Aero Arc',
          status: 'active',
          acceptanceStatus: 'accepted',
          remoteIdStatus: 'broadcasting',
        ),
        maintenanceEvents: [],
        liveStateAvailable: true,
        liveState: LiveAircraftState(
          aircraftId: 'aircraft-1',
          relayId: 'relay-1',
          connected: true,
        ),
        readiness: Readiness(status: 'ready', reasons: []),
        currentIntent: OperationalIntent(
          id: 'intent-1',
          aircraftId: 'aircraft-1',
          version: 3,
          name: 'Pipeline',
          summary: 'Pipeline patrol',
          authorizationPath: 'demo',
          populationCategory: 'cat_1',
          status: 'active',
          conformanceRequired: true,
        ),
      ),
      AircraftDashboard(
        aircraft: Aircraft(
          id: 'aircraft-2',
          tailNumber: 'N200AA',
          name: 'Hawk 2',
          model: 'ArcRunner',
          manufacturer: 'Aero Arc',
          status: 'active',
          acceptanceStatus: 'accepted',
          remoteIdStatus: 'broadcasting',
        ),
        maintenanceEvents: [],
        liveStateAvailable: false,
        readiness: Readiness(
          status: 'blocked',
          reasons: ['Remote ID offline', 'Open maintenance hold'],
        ),
      ),
    ],
  );
}
