import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/widgets/dashboard_ui.dart';

void main() {
  test('statusColor maps critical backend enum values', () {
    expect(statusColor('ready'), const Color(0xFF00CFA0));
    expect(statusColor('non_conforming'), const Color(0xFFE14A5B));
    expect(statusColor('review'), const Color(0xFFE4A100));
    expect(statusColor('fresh'), const Color(0xFF00CFA0));
    expect(statusColor('stale'), const Color(0xFFE4A100));
    expect(statusColor('unavailable'), const Color(0xFF7F90B6));
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
}
