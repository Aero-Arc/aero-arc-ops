import 'dart:convert';
import 'dart:io';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/overview_page.dart';
import 'package:aero_arc_web/widgets/selected_operation_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

import 'aircraft_map_screen_test.dart' show sampleMapView;

OperationsDashboard fixture() => OperationsDashboard.fromJson({
  'live_aircraft': [
    jsonDecode(
      File('test/fixtures/live_aircraft_state.json').readAsStringSync(),
    ),
  ],
  'operational_intents': [
    {
      'id': 'intent-1',
      'version': 1,
      'aircraft_id': 'aircraft-1',
      'name': 'Bayou Inspection 042',
      'status': 'active',
      'updated_at': '2026-08-11T12:00:00Z',
    },
  ],
  'conformance': [
    {
      'id': 'conformance-1',
      'aircraft_id': 'aircraft-1',
      'intent_id': 'intent-1',
      'status': 'warning',
      'alert_count': 1,
      'updated_at': '2026-08-11T12:00:01Z',
    },
  ],
});

void main() {
  testWidgets(
    'selected mission layers use existing map data and survive layer failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OverviewPage(
              load: () async => fixture(),
              loadMap: (_) async {
                if (fail) throw Exception('map unavailable');
                return sampleMapView();
              },
              renderTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bayou Inspection 042').first);
      await tester.pumpAndSettle();
      expect(find.byType(PolygonLayer<Object>), findsOneWidget);
      expect(find.byTooltip('Close inspector'), findsOneWidget);
      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();
      fail = true;
      await tester.tap(find.text('Bayou Inspection 042').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Mission layers unavailable'), findsWidgets);
      await revealBattery(tester);
      await tester.pumpAndSettle();
      expect(find.text('76.0 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [1600.0, 1200.0, 1024.0, 768.0, 390.0]) {
    testWidgets('overview fits $width and preserves sampled telemetry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: OverviewPage(load: () async => fixture(), renderTiles: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('76% · stale'), findsOneWidget);
      final mission = find.text('Bayou Inspection 042').first;
      await tester.ensureVisible(mission);
      await tester.tap(mission);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close inspector'), findsOneWidget);
      await revealBattery(tester);
      await tester.pumpAndSettle();
      expect(find.text('76.0 %'), findsOneWidget);
      expect(find.textContaining('Stale ·'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('empty fleet and unavailable conformance remain unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewPage(
            load: () async => const OperationsDashboard(
              metrics: [],
              operationalIntents: [],
              conformance: [],
            ),
            renderTiles: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('Awaiting aircraft position telemetry'), findsOneWidget);
    expect(find.text('No active operational intents'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('timeline filters and map layers respond to selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: OverviewPage(load: () async => fixture(), renderTiles: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final filter = find.widgetWithText(ChoiceChip, 'Conformance');
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.text('Bayou Inspection 042 · Active'), findsNothing);
    expect(find.text('aircraft-1 · Warning'), findsWidgets);
    final layers = find.byTooltip('Map layers');
    await tester.ensureVisible(layers);
    await tester.tap(layers);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> revealBattery(WidgetTester tester) async {
  final inspector = find.byType(SelectedOperationInspector);
  final list = find.descendant(of: inspector, matching: find.byType(ListView));
  await tester.ensureVisible(list);
  await tester.scrollUntilVisible(
    find.text('76.0 %'),
    120,
    scrollable: find.descendant(
      of: inspector,
      matching: find.byType(Scrollable),
    ),
  );
}
