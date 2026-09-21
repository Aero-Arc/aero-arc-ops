import 'package:aero_arc_web/widgets/animated_aircraft_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('heading and longitude take the short path across their wrap', () {
    expect(shortestAngleDelta(359, 1), 2);
    expect(shortestAngleDelta(1, 359), -2);
    expect(
      interpolateMapPosition(
        const LatLng(0, 179),
        const LatLng(0, -179),
        .5,
      ).longitude.abs(),
      180,
    );
  });

  testWidgets(
    'interpolates received samples, retargets continuously, and never extrapolates',
    (tester) async {
      LatLng? shown;
      double? shownHeading;
      Future<void> sample(
        double latitude,
        int second, {
        bool fresh = true,
        bool reduced = false,
      }) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: AnimatedAircraftPosition(
              point: LatLng(latitude, 0),
              heading: second == 0 ? 359 : 1,
              recordedAt: DateTime(2026, 1, 1, 0, 0, second),
              fresh: fresh,
              duration: const Duration(seconds: 1),
              builder: (_, point, heading) {
                shown = point;
                shownHeading = heading;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await sample(0, 0);
      await sample(10, 1);
      expect(shown!.latitude, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(shown!.latitude, closeTo(5, .01));
      expect(shownHeading! % 360, closeTo(0, .01));
      await sample(20, 2);
      expect(shown!.latitude, closeTo(5, .01));
      await tester.pump(const Duration(milliseconds: 500));
      expect(shown!.latitude, closeTo(12.5, .01));
      await tester.pump(const Duration(seconds: 1));
      expect(shown!.latitude, 20);
      await tester.pump(const Duration(seconds: 10));
      expect(shown!.latitude, 20);

      await sample(30, 3);
      await tester.pump(const Duration(milliseconds: 200));
      await sample(30, 3, fresh: false);
      expect(shown!.latitude, 30);
      await tester.pump(const Duration(seconds: 1));
      expect(shown!.latitude, 30);

      await sample(40, 4);
      expect(
        shown!.latitude,
        40,
      ); // Recovery from stale data snaps to evidence.
      await sample(50, 30);
      expect(
        shown!.latitude,
        50,
      ); // Long gaps do not animate an invented flight.
      await sample(60, 31, reduced: true);
      expect(shown!.latitude, 60);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('duplicate sample rebuilds do not restart movement', (
    tester,
  ) async {
    var shown = 0.0;
    Future<void> sample(double latitude, int second) => tester.pumpWidget(
      MaterialApp(
        home: AnimatedAircraftPosition(
          point: LatLng(latitude, 0),
          heading: 0,
          recordedAt: DateTime(2026, 1, 1, 0, 0, second),
          fresh: true,
          duration: const Duration(seconds: 1),
          builder: (_, point, _) {
            shown = point.latitude;
            return const SizedBox();
          },
        ),
      ),
    );
    await sample(0, 0);
    await sample(10, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await sample(10, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(shown, 10);
    await tester.pumpWidget(const SizedBox());
  });
}
