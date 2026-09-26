/// One durable command and its independently recorded execution evidence.
class FlightCommand {
  const FlightCommand({
    required this.id,
    required this.type,
    required this.state,
    required this.observationState,
    required this.attempts,
    required this.events,
  });
  final String id, type, state, observationState;
  final int attempts;
  final List<FlightCommandEvent> events;
  bool get unresolved =>
      !['applied', 'rejected', 'failed', 'timed_out'].contains(state);
  String? get progressLabel {
    if (!['accepted', 'dispatched', 'acknowledged'].contains(state)) {
      return null;
    }
    if (events.any((e) => e.stage == 'awaiting_ack')) {
      return 'Awaiting autopilot ACK';
    }
    if (events.any((e) => e.stage == 'verifying_mission')) {
      return 'Verifying onboard mission';
    }
    return null;
  }

  int get recoveryDeliveries => attempts > 1 ? attempts - 1 : 0;

  factory FlightCommand.fromJson(Map<String, dynamic> json) => FlightCommand(
    id: json['id'] as String,
    type: json['type'] as String,
    state: json['state'] as String,
    observationState: json['observation_state'] as String? ?? 'pending',
    attempts: json['attempts'] as int? ?? 0,
    events: (json['events'] as List? ?? [])
        .map((e) => FlightCommandEvent.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// An immutable source event; occurrence and receipt times may differ.
class FlightCommandEvent {
  const FlightCommandEvent({
    required this.stage,
    required this.occurredAt,
    required this.receivedAt,
    required this.source,
    required this.message,
  });
  final String stage, source, message;
  final DateTime occurredAt, receivedAt;
  factory FlightCommandEvent.fromJson(Map<String, dynamic> json) =>
      FlightCommandEvent(
        stage: json['stage'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        receivedAt: DateTime.parse(json['received_at'] as String),
        source: json['source'] as String,
        message: json['message'] as String? ?? '',
      );
}
