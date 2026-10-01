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
    FlightCommandEvent? latest;
    for (final event in events) {
      if (!['awaiting_ack', 'verifying_mission'].contains(event.stage)) {
        continue;
      }
      if (latest == null ||
          event.occurredAt.isAfter(latest.occurredAt) ||
          (event.occurredAt == latest.occurredAt &&
              !event.receivedAt.isBefore(latest.receivedAt))) {
        latest = event;
      }
    }
    if (latest?.stage == 'awaiting_ack') return 'Awaiting autopilot ACK';
    if (latest?.stage == 'verifying_mission') {
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

/// Persisted aircraft evidence and API cleanup progress; receipt is not closure.
class FlightCompletion {
  const FlightCompletion({
    required this.state,
    required this.outcome,
    required this.attempts,
    required this.error,
    required this.landedAt,
    required this.disarmedAt,
  });
  final String state, outcome, error;
  final int attempts;
  final DateTime? landedAt, disarmedAt;
  factory FlightCompletion.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence'] as Map<String, dynamic>? ?? {};
    DateTime? timestamp(dynamic value) {
      final ns = int.tryParse('$value');
      return ns == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(ns ~/ 1000, isUtc: true);
    }

    return FlightCompletion(
      state: json['state'] as String,
      outcome: evidence['outcome'] as String? ?? '',
      attempts: json['attempts'] as int? ?? 0,
      error: json['error'] as String? ?? '',
      landedAt: timestamp(evidence['landed_at_unix_ns']),
      disarmedAt: timestamp(evidence['disarmed_at_unix_ns']),
    );
  }
}
