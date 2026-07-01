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
    expect(find.text('Loading'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('aircraft map action navigates to aircraft map route', (
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
            builder: (_) => Text('map:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final mapAction = find.byTooltip('Open aircraft map').first;
    await tester.ensureVisible(mapAction);
    await tester.tap(mapAction);
    await tester.pumpAndSettle();

    expect(find.text('map:/aircraft/aircraft-1/map'), findsOneWidget);
  });

  testWidgets('intent workflow route keeps desktop sidebar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const AppShell(
          section: AppSection.aircraft,
          intentAircraftId: 'aircraft-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aero Arc'), findsOneWidget);
    expect(find.text('Aircraft'), findsWidgets);
    expect(find.text('New Mission Intent'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Mission aircraft-1'),
      findsOneWidget,
    );
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
