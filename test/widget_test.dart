import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/main.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/agents_page.dart';

void main() {
  testWidgets('shows readiness dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AeroArcApp());

    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Readiness Overview'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
  });

  testWidgets('aircraft list click navigates to aircraft map route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentsPage(load: () async => sampleAircraftList()),
        ),
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('map:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final aircraftName = find.text('Eagle 1').first;
    await tester.ensureVisible(aircraftName);
    await tester.tap(aircraftName);
    await tester.pumpAndSettle();

    expect(find.text('map:/aircraft/aircraft-1/map'), findsOneWidget);
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
        liveStateAvailable: false,
        readiness: Readiness(status: 'ready', reasons: []),
      ),
    ],
  );
}
