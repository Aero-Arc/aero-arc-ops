import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/widgets/dashboard_ui.dart';

void main() {
  test('percentage-point formatting does not scale sub-one values', () {
    expect(formatPercentagePoints(0.4), '0.4%');
    expect(formatPercentagePoints(0.04), '0.04%');
    expect(formatPercentagePoints(43.2), '43.2%');
    expect(formatPercentagePoints(76), '76%');
    expect(formatPercentagePoints(null), 'Not provided');
  });

  test('statusColor maps critical backend enum values', () {
    expect(statusColor('ready'), const Color(0xFF21C997));
    expect(statusColor('non_conforming'), const Color(0xFFE14A5B));
    expect(statusColor('review'), const Color(0xFFE4A100));
    expect(statusColor('fresh'), const Color(0xFF21C997));
    expect(statusColor('stale'), const Color(0xFFE4A100));
    expect(statusColor('unavailable'), const Color(0xFF8797AB));
    expect(statusColor('validated'), const Color(0xFF21C997));
    expect(statusColor('not_imported'), const Color(0xFF8797AB));
    expect(statusColor('binding_mismatch'), const Color(0xFFE14A5B));
    expect(statusColor('applied'), const Color(0xFF21C997));
    expect(statusColor('outcome_unknown'), const Color(0xFFE4A100));
    expect(statusColor('temporary_error'), const Color(0xFFE4A100));
    expect(statusColor('onboard_mission_mismatch'), const Color(0xFFE14A5B));
  });

  testWidgets('DashboardPage renders loaded data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: DashboardPage<String>(
          title: 'Readiness',
          subtitle: 'Operational posture',
          load: () async => 'loaded',
          builder: (context, data) => [Text(data)],
        ),
      ),
    );

    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('loaded'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('DashboardPage periodically refreshes live data', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage<String>(
          title: 'Operations',
          subtitle: 'Live state',
          autoRefreshInterval: const Duration(seconds: 5),
          load: () async => 'load-${++calls}',
          builder: (context, data) => [Text(data)],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('load-1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('load-2'), findsOneWidget);
  });

  testWidgets('background polling does not rebuild while waiting or overlap', (
    tester,
  ) async {
    final loads = <Completer<String>>[];
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage<String>(
          title: 'Operations',
          subtitle: 'Live',
          autoRefreshInterval: const Duration(seconds: 1),
          load: () {
            final pending = Completer<String>();
            loads.add(pending);
            return pending.future;
          },
          builder: (context, data) {
            builds++;
            return [Text(data)];
          },
        ),
      ),
    );
    loads.single.complete('first');
    await tester.pump();
    final initialBuilds = builds;
    await tester.pump(const Duration(seconds: 1));
    expect(loads, hasLength(2));
    expect(builds, initialBuilds);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(loads, hasLength(2));
    expect(builds, initialBuilds);
    loads[1].complete('second');
    await tester.pump();
    await tester.pump(); // Paint the frame scheduled by background completion.
    expect(builds, initialBuilds + 1);
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    loads.last.completeError(StateError('Disposed request failed'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure preserves data and later success replaces it', (
    tester,
  ) async {
    final loads = <Completer<String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage<String>(
          title: 'Operations',
          subtitle: 'Live state',
          autoRefreshInterval: const Duration(seconds: 5),
          load: () {
            final load = Completer<String>();
            loads.add(load);
            return load.future;
          },
          builder: (context, data) => [Text(data)],
        ),
      ),
    );

    loads.single.complete('current operations');
    await tester.pump();
    expect(find.text('current operations'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(loads, hasLength(2));
    loads[1].completeError(Exception('temporary registry outage'));
    await tester.pump();
    await tester.pump(); // Background requests no longer pre-schedule a frame.

    expect(find.text('current operations'), findsOneWidget);
    expect(find.text('Refresh failed'), findsOneWidget);
    expect(find.textContaining('temporary registry outage'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(loads, hasLength(3));
    loads[2].complete('recovered operations');
    await tester.pump();

    expect(find.text('recovered operations'), findsOneWidget);
    expect(find.text('current operations'), findsNothing);
    expect(find.text('Refresh failed'), findsNothing);
  });
}
