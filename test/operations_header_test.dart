import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aero_arc_web/widgets/operations_header.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('operator header fits at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 200),
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const OperationsHeader(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Aero Arc Operations'), findsOneWidget);
      expect(
        find.textContaining(' UTC'),
        width < 650 ? findsNothing : findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
