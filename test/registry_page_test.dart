import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/registry_page.dart';

void main() {
  testWidgets('operations page exposes intent actions and attention filters', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: RegistryPage(load: () async => sampleOperationsDashboard()),
        ),
        onGenerateRoute: (settings) {
          routeArguments = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('route:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Assigned intents, launch posture, active windows, and conformance attention.',
      ),
      findsOneWidget,
    );
    expect(find.text('Intent Register'), findsOneWidget);
    expect(find.text('Operational Intent Register'), findsNothing);
    expect(find.text('Needs Attention'), findsOneWidget);
    expect(find.text('Conformance Attention'), findsOneWidget);
    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsOneWidget);
    expect(find.byTooltip('Open intent workflow'), findsNWidgets(2));

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsOneWidget);

    await tester.tap(find.text('Ready to activate'));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Pipeline v2'));
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/intent/new'), findsOneWidget);
    expect(routeArguments, isNotNull);

    Navigator.of(
      tester.element(find.text('route:/aircraft/aircraft-1/intent/new')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'aircraft-2'));
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-2/map'), findsOneWidget);
  });
}

OperationsDashboard sampleOperationsDashboard() {
  return const OperationsDashboard(
    metrics: [
      DashboardMetric(label: 'Active intents', value: '1', status: 'ready'),
    ],
    operationalIntents: [
      OperationalIntent(
        id: 'intent-1',
        aircraftId: 'aircraft-1',
        version: 2,
        name: 'Pipeline',
        summary: 'Pipeline patrol',
        authorizationPath: 'permit',
        populationCategory: 'cat_2',
        status: 'accepted',
        conformanceRequired: true,
      ),
      OperationalIntent(
        id: 'intent-2',
        aircraftId: 'aircraft-2',
        version: 1,
        name: 'Survey',
        summary: 'Survey grid',
        authorizationPath: 'demo',
        populationCategory: 'cat_1',
        status: 'active',
        conformanceRequired: true,
      ),
    ],
    conformance: [
      ConformanceSummary(
        id: 'summary-1',
        intentId: 'intent-2',
        intentVersion: 1,
        aircraftId: 'aircraft-2',
        status: 'deviating',
        alertCount: 2,
        reportabilityStatus: 'review',
      ),
    ],
  );
}
