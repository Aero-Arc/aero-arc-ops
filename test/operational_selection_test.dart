import 'dart:async';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/overview_page.dart';
import 'package:aero_arc_web/widgets/operational_selection.dart';
import 'package:aero_arc_web/widgets/selected_operation_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overview_page_test.dart' show fixture;
import 'aircraft_map_screen_test.dart' show sampleMapView;

void main() {
  test(
    'identity selection is idempotent and preserves separate operations',
    () {
      final selection = OperationalSelection();
      addTearDown(selection.dispose);
      var notifications = 0;
      selection.addListener(() => notifications++);
      selection.remember(fixture().operationalIntents);
      expect(selection.intent('intent-1')?.name, 'Bayou Inspection 042');
      selection.select('aircraft-1', intent: 'intent-1');
      selection.select('aircraft-1', intent: 'intent-1');
      expect(notifications, 1);
      selection.select('aircraft-1', intent: 'intent-2');
      expect(notifications, 2);
      selection.clear();
      selection.clear();
      expect(notifications, 3);
      expect(selection.aircraftId, isNull);
      expect(selection.intentId, isNull);
    },
  );

  testWidgets(
    'external focus opens inspector; reselect does not reload; late map cannot overwrite focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selection = OperationalSelection();
      addTearDown(selection.dispose);
      final first = Completer<AircraftMapView>();
      var requests = 0;
      final original = fixture();
      final data = OperationsDashboard(
        metrics: original.metrics,
        liveAircraft: original.liveAircraft,
        conformance: original.conformance,
        operationalIntents: [
          ...original.operationalIntents,
          OperationalIntent.fromJson({
            'id': 'intent-2',
            'version': 1,
            'aircraft_id': 'aircraft-2',
            'name': 'Warehouse Survey',
            'status': 'active',
          }),
        ],
      );
      await tester.pumpWidget(
        OperationalSelectionScope(
          selection: selection,
          child: MaterialApp(
            home: Scaffold(
              body: OverviewPage(
                renderTiles: false,
                load: () async => data,
                loadMap: (id) {
                  requests++;
                  return id == 'aircraft-1'
                      ? first.future
                      : Future.error(Exception('Unavailable'));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      selection.select('aircraft-1', intent: 'intent-1');
      await tester.pumpAndSettle();
      expect(find.byType(SelectedOperationInspector), findsOneWidget);
      expect(requests, 1);
      selection.select('aircraft-1', intent: 'intent-1');
      await tester.pumpAndSettle();
      expect(requests, 1);
      selection.select('aircraft-2', intent: 'intent-2');
      await tester.pumpAndSettle();
      first.complete(sampleMapView());
      await tester.pumpAndSettle();
      final inspector = tester.widget<SelectedOperationInspector>(
        find.byType(SelectedOperationInspector),
      );
      expect(inspector.aircraftId, 'aircraft-2');
      expect(inspector.intent?.id, 'intent-2');
      expect(
        inspector.state,
        isNull,
      ); // No invented telemetry for the second aircraft.
      expect(inspector.mapView, isNull);
      expect(inspector.conformance, isNull);
      expect(find.text('Fleet-wide alerts'), findsOneWidget);
      expect(find.text('Selected operation updates'), findsOneWidget);
      selection.select('aircraft-1', intent: 'historical-operation');
      await tester.pumpAndSettle();
      expect(selection.intentId, 'historical-operation');
      expect(
        tester
            .widget<SelectedOperationInspector>(
              find.byType(SelectedOperationInspector),
            )
            .intent,
        isNull,
      );
      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();
      expect(selection.aircraftId, isNull);
      expect(find.byType(SelectedOperationInspector), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mismatched intent revision hides mission overlays', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewPage(
            renderTiles: false,
            load: () async => fixture(),
            loadMap: (_) async => sampleMapView(intentVersion: 2),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayou Inspection 042').first);
    await tester.pumpAndSettle();
    final inspector = tester.widget<SelectedOperationInspector>(
      find.byType(SelectedOperationInspector),
    );
    expect(inspector.mapView, isNull);
    expect(inspector.error, contains('another operation'));
    expect(inspector.state?.aircraftId, 'aircraft-1');
    await tester.pumpWidget(const SizedBox());
  });
}
