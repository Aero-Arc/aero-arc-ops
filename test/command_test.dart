import 'package:flutter_test/flutter_test.dart';
import 'package:aero_arc_web/models/command.dart';

void main() {
  test('progress uses latest evidence regardless of delivery order', () {
    final first = FlightCommandEvent(
      stage: 'awaiting_ack',
      occurredAt: DateTime.utc(2026),
      receivedAt: DateTime.utc(2026),
      source: 'agent',
      message: '',
    );
    final second = FlightCommandEvent(
      stage: 'verifying_mission',
      occurredAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      receivedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
      source: 'agent',
      message: '',
    );
    for (final events in [
      [first, second],
      [second, first],
    ]) {
      final immutable = List<FlightCommandEvent>.unmodifiable(events);
      final command = FlightCommand(
        id: 'upload',
        type: 'MISSION_UPLOAD',
        state: 'acknowledged',
        observationState: 'pending',
        attempts: 1,
        events: immutable,
      );
      expect(command.progressLabel, 'Verifying onboard mission');
      expect(command.events, orderedEquals(events));
    }
  });
}
