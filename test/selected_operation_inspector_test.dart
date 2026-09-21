import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/widgets/dashboard_ui.dart';
import 'package:aero_arc_web/widgets/selected_operation_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final intent = OperationalIntent.fromJson({
    'id': 'intent',
    'version': 2,
    'aircraft_id': 'AA-07',
    'planned_end_at': '2026-09-21T12:00:00Z',
  });
  ConformanceSummary summary({
    String monitoring = 'current',
    int version = 2,
    bool spatialFresh = true,
  }) => ConformanceSummary.fromJson({
    'intent_id': 'intent',
    'intent_version': version,
    'aircraft_id': 'AA-07',
    'monitoring_status': monitoring,
    'observed_at': '2026-09-21T12:01:05Z',
    'violations': [
      {'type': 'temporal_deviation', 'phase': 'open', 'worst_deviation_m': 999},
      {
        'type': 'lateral_deviation',
        'phase': 'open',
        'worst_deviation_m': 12.2,
        'last_observed_at': spatialFresh
            ? '2026-09-21T12:01:05Z'
            : '2026-09-21T12:00:00Z',
      },
      {
        'type': 'altitude_deviation',
        'phase': 'clear',
        'worst_deviation_m': 0,
        'last_observed_at': '2026-09-21T12:01:05Z',
      },
    ],
  });

  test(
    'temporal offset uses evaluation time, never distance or wall clock',
    () {
      expect(
        inspectorDeviation(summary(), intent, 'temporal_deviation'),
        'Open · 65 sec past planned end at evaluation',
      );
      expect(
        inspectorDeviation(summary(version: 1), intent, 'temporal_deviation'),
        'Open · timing details unavailable',
      );
    },
  );
  test(
    'spatial maxima are labeled and stale axes are not current evidence',
    () {
      expect(
        inspectorDeviation(summary(), intent, 'lateral_deviation'),
        'Open · worst 12.2 m (recorded)',
      );
      expect(
        inspectorDeviation(summary(), intent, 'altitude_deviation'),
        'Clear · worst 0.0 m (recorded)',
      );
      expect(
        inspectorDeviation(
          summary(spatialFresh: false),
          intent,
          'lateral_deviation',
        ),
        'Not evaluated',
      );
      expect(
        inspectorDeviation(
          summary(monitoring: 'stale'),
          intent,
          'temporal_deviation',
        ),
        'Not evaluated',
      );
      expect(
        inspectorDeviation(null, intent, 'lateral_deviation'),
        'Not evaluated',
      );
    },
  );
  test(
    'unavailable health is neutral and distinct from degraded and healthy',
    () {
      expect(statusColor('unavailable'), statusColor('unknown'));
      expect(statusColor('unavailable'), isNot(statusColor('degraded')));
      expect(statusColor('unavailable'), isNot(statusColor('healthy')));
      expect(statusColor('stale'), statusColor('warning'));
      expect(statusColor('fresh'), statusColor('healthy'));
    },
  );
}
