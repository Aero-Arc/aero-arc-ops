import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/main.dart';

void main() {
  testWidgets('shows readiness dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AeroArcApp());

    expect(find.text('Readiness'), findsOneWidget);
    expect(find.text('Readiness Overview'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
  });
}
