import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/widgets/dashboard_ui.dart';

void main() {
  test('statusColor maps critical backend enum values', () {
    expect(statusColor('ready'), const Color(0xFF00CFA0));
    expect(statusColor('non_conforming'), const Color(0xFFE14A5B));
    expect(statusColor('review'), const Color(0xFFE4A100));
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
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('loaded'), findsOneWidget);
  });
}
