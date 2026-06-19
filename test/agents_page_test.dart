import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/agents_page.dart';

void main() {
  testWidgets('aircraft intent action opens create intent route', (
    WidgetTester tester,
  ) async {
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

    final createIntent = find.byTooltip('Create intent');
    await tester.ensureVisible(createIntent);
    await tester.tap(createIntent);
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
        liveStateAvailable: false,
        readiness: Readiness(status: 'ready', reasons: []),
      ),
    ],
  );
}
