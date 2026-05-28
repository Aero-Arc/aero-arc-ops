import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/main.dart';

void main() {
  testWidgets('shows overview shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AeroArcApp());

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('System Overview'), findsOneWidget);
  });
}
