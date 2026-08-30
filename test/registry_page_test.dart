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
        'Live aircraft connectivity, telemetry freshness, assigned intents, and conformance attention.',
      ),
      findsOneWidget,
    );
    expect(find.text('Intent Register'), findsOneWidget);
    expect(find.text('Live Aircraft'), findsOneWidget);
    expect(find.text('Connected aircraft'), findsOneWidget);
    expect(find.textContaining('Relay relay-central-1'), findsOneWidget);
    expect(find.textContaining('Battery 76%'), findsWidgets);
    expect(find.textContaining('Vehicle · Missing · No sample'), findsWidgets);
    expect(find.textContaining('Stale'), findsWidgets);
    expect(find.text('Operational Intent Register'), findsNothing);
    expect(find.text('Needs Attention'), findsOneWidget);
    expect(find.text('Conformance Attention'), findsOneWidget);
    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsOneWidget);
    expect(find.textContaining('intent-1 v1 / aircraft-1'), findsNothing);
    expect(find.byTooltip('Open intent workflow'), findsNWidgets(2));

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsOneWidget);

    await tester.tap(find.text('Ready to activate'));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v2'), findsOneWidget);
    expect(find.text('Survey v1'), findsNothing);

    await tester.tap(find.text('Conformance alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline v2'), findsNothing);
    expect(find.text('Survey v1'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pipeline v2'));
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/intent/new'), findsOneWidget);
    expect(routeArguments, isNotNull);

    Navigator.of(
      tester.element(find.text('route:/aircraft/aircraft-1/intent/new')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-2/map'), findsOneWidget);
  });

  testWidgets('transitional live conformance is surfaced as attention', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: RegistryPage(
            load: () async => transitionalOperationsDashboard(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conformance alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Transition v1'), findsOneWidget);
    expect(find.text('Armed'), findsWidgets);
    expect(find.textContaining('Armed monitoring'), findsWidgets);
  });

  testWidgets('active intent past planned end remains active and is overdue', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final dashboard = OperationsDashboard(
      metrics: const [],
      operationalIntents: [
        OperationalIntent(
          id: 'intent-overdue',
          aircraftId: 'aircraft-overdue',
          version: 1,
          name: 'Overrun mission',
          summary: 'Aircraft is still operating',
          authorizationPath: 'demo',
          populationCategory: 'cat_1',
          status: 'active',
          conformanceRequired: true,
          plannedStartAt: DateTime.utc(2020, 1, 1, 11),
          plannedEndAt: DateTime.utc(2020, 1, 1, 12),
        ),
      ],
      conformance: const [],
      liveAircraft: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: RegistryPage(load: () async => dashboard)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsWidgets);
    expect(
      find.textContaining('monitoring must continue until explicit completion'),
      findsOneWidget,
    );

    await tester.tap(find.text('Needs attention'));
    await tester.pumpAndSettle();
    expect(find.text('Overrun mission v1'), findsOneWidget);
  });

  testWidgets(
    'new assignment generation wins before its local evaluation revision',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dashboard = OperationsDashboard(
        metrics: const [],
        operationalIntents: const [
          OperationalIntent(
            id: 'intent-generation',
            aircraftId: 'aircraft-generation',
            version: 1,
            name: 'Generation',
            summary: 'Assignment replacement',
            authorizationPath: 'demo',
            populationCategory: 'cat_1',
            status: 'active',
            conformanceRequired: true,
          ),
        ],
        conformance: [
          ConformanceSummary(
            id: 'old-generation',
            intentId: 'intent-generation',
            intentVersion: 1,
            aircraftId: 'aircraft-generation',
            status: 'non_conforming',
            alertCount: 0,
            reportabilityStatus: 'no',
            assignmentId: 'assignment-old',
            assignmentGeneration: 1,
            evaluationRevision: 99,
            condition: 'non_conforming',
            monitoringStatus: 'current',
            recordingStatus: 'confirmed',
            observedAt: DateTime.utc(2026, 8, 30, 10),
          ),
          ConformanceSummary(
            id: 'new-generation',
            intentId: 'intent-generation',
            intentVersion: 1,
            aircraftId: 'aircraft-generation',
            status: 'conforming',
            alertCount: 0,
            reportabilityStatus: 'no',
            assignmentId: 'assignment-new',
            assignmentGeneration: 2,
            evaluationRevision: 1,
            condition: 'conforming',
            monitoringStatus: 'current',
            recordingStatus: 'confirmed',
            observedAt: DateTime.utc(2026, 8, 30, 9),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(body: RegistryPage(load: () async => dashboard)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conforming'), findsWidgets);
      expect(find.text('Non Conforming'), findsNothing);
      expect(find.text('No conformance alerts are linked.'), findsOneWidget);
    },
  );

  testWidgets('stale or missing spatial phases are shown as not evaluated', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final dashboard = OperationsDashboard(
      metrics: const [],
      operationalIntents: const [
        OperationalIntent(
          id: 'intent-spatial',
          aircraftId: 'aircraft-spatial',
          version: 1,
          name: 'Spatial evidence gap',
          summary: 'No unambiguous reference geometry',
          authorizationPath: 'demo',
          populationCategory: 'cat_1',
          status: 'active',
          conformanceRequired: true,
        ),
      ],
      conformance: [
        ConformanceSummary(
          id: 'summary-spatial',
          intentId: 'intent-spatial',
          intentVersion: 1,
          aircraftId: 'aircraft-spatial',
          status: 'non_conforming',
          alertCount: 0,
          reportabilityStatus: 'no',
          assignmentId: 'assignment-spatial',
          assignmentGeneration: 3,
          evaluationRevision: 8,
          condition: 'non_conforming',
          monitoringStatus: 'current',
          recordingStatus: 'confirmed',
          observedAt: DateTime.utc(2026, 8, 30, 10),
          frameId: 'frame-8',
          walId: 'wal-1',
          walSequence: 8,
          violations: [
            ConformanceViolation(
              type: 'lateral_deviation',
              phase: 'open',
              lastObservedAt: DateTime.utc(2026, 8, 30, 9, 59),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: RegistryPage(load: () async => dashboard)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('intent-spatial v1').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Open retained from'), findsOneWidget);
    expect(find.text('Not evaluated at this watermark'), findsOneWidget);
    expect(find.text('wal-1 · 8'), findsOneWidget);
    expect(find.text('frame-8'), findsOneWidget);
  });
}

OperationsDashboard transitionalOperationsDashboard() {
  return OperationsDashboard(
    metrics: const [],
    operationalIntents: const [
      OperationalIntent(
        id: 'intent-transition',
        aircraftId: 'aircraft-transition',
        version: 1,
        name: 'Transition',
        summary: 'Assignment cutover',
        authorizationPath: 'permit',
        populationCategory: 'cat_1',
        status: 'active',
        conformanceRequired: true,
      ),
    ],
    conformance: const [
      ConformanceSummary(
        id: 'summary-transition',
        intentId: 'intent-transition',
        intentVersion: 1,
        aircraftId: 'aircraft-transition',
        status: 'conforming',
        alertCount: 0,
        reportabilityStatus: 'no',
        assignmentId: 'intent-transition',
        assignmentGeneration: 1,
        evaluationRevision: 1,
        condition: 'conforming',
        monitoringStatus: 'armed',
        recordingStatus: 'pending',
      ),
    ],
    liveAircraft: const [],
  );
}

OperationsDashboard sampleOperationsDashboard() {
  return OperationsDashboard(
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
        id: 'summary-superseded',
        intentId: 'intent-1',
        intentVersion: 1,
        aircraftId: 'aircraft-1',
        status: 'non_conforming',
        alertCount: 1,
        reportabilityStatus: 'review',
        assignmentId: 'intent-1-v1',
        assignmentGeneration: 1,
        evaluationRevision: 99,
        condition: 'non_conforming',
        monitoringStatus: 'current',
        recordingStatus: 'confirmed',
        observedAt: DateTime.utc(2099, 8, 11, 12),
        violations: const [
          ConformanceViolation(type: 'lateral_deviation', phase: 'open'),
        ],
      ),
      ConformanceSummary(
        id: 'summary-1',
        intentId: 'intent-2',
        intentVersion: 1,
        aircraftId: 'aircraft-2',
        status: 'non_conforming',
        alertCount: 0,
        reportabilityStatus: 'no',
        assignmentId: 'intent-2',
        assignmentGeneration: 1,
        evaluationRevision: 7,
        evaluationId: 'evaluation-7',
        condition: 'non_conforming',
        monitoringStatus: 'current',
        recordingStatus: 'confirmed',
        violations: const [
          ConformanceViolation(type: 'lateral_deviation', phase: 'opening'),
        ],
      ),
    ],
    liveAircraft: [
      AircraftLiveState(
        aircraftId: 'aircraft-1',
        agentId: 'agent-1',
        connection: AircraftConnectionState(
          aircraftId: 'aircraft-1',
          agentId: 'agent-1',
          relayId: 'relay-central-1',
          connected: true,
          status: 'connected',
          lastHeartbeatAt: DateTime(2099, 8, 11, 12, 0, 29),
        ),
        telemetry: AircraftTelemetryState(
          status: 'stale',
          lastObservedAt: DateTime(2099, 8, 11, 12, 0, 30),
          position: PositionTelemetry(
            status: 'fresh',
            recordedAt: DateTime(2099, 8, 11, 12, 0, 30),
            latitudeDeg: 29.7604,
            longitudeDeg: -95.3698,
          ),
          battery: BatteryTelemetry(
            status: 'stale',
            recordedAt: DateTime(2099, 8, 11, 11, 59, 50),
            batteryId: 0,
            remainingPct: 76,
          ),
        ),
      ),
      AircraftLiveState(
        aircraftId: 'aircraft-2',
        connection: AircraftConnectionState(
          aircraftId: 'aircraft-2',
          connected: false,
          status: 'offline',
        ),
        telemetry: AircraftTelemetryState(status: 'missing'),
      ),
    ],
  );
}
