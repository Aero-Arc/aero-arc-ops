import 'aero_arc_models.dart';

/// Durable transition evidence, distinct from a Registry live summary.
class ConformanceHistoryEvent {
  const ConformanceHistoryEvent({
    required this.id,
    required this.assignmentId,
    required this.generation,
    required this.intentId,
    required this.intentVersion,
    required this.aircraftId,
    required this.flightId,
    required this.incidentId,
    required this.transition,
    required this.violationType,
    required this.observedAt,
    required this.frameId,
    required this.revision,
    this.deviationM,
  });
  final String id, assignmentId, intentId, aircraftId, flightId, incidentId;
  final String transition, violationType, frameId;
  final int generation, intentVersion, revision;
  final DateTime observedAt;
  final double? deviationM;
  factory ConformanceHistoryEvent.fromJson(Map<String, dynamic> json) =>
      ConformanceHistoryEvent(
        id: json['id'] as String,
        assignmentId: json['assignment_id'] as String,
        generation: (json['assignment_generation'] as num).toInt(),
        intentId: json['intent_id'] as String,
        intentVersion: (json['intent_version'] as num).toInt(),
        aircraftId: json['aircraft_id'] as String,
        flightId: json['flight_id'] as String,
        incidentId: json['incident_id'] as String,
        transition: json['transition'] as String,
        violationType: json['violation_type'] as String,
        observedAt: DateTime.parse(json['observed_at'] as String),
        frameId: json['frame_id'] as String,
        revision: (json['evaluation_revision'] as num).toInt(),
        deviationM: asNullableDouble(json['deviation_m']),
      );
}

class ConformanceHistoryPage {
  const ConformanceHistoryPage({required this.events, this.nextPageToken});
  final List<ConformanceHistoryEvent> events;
  final String? nextPageToken;
  factory ConformanceHistoryPage.fromJson(Map<String, dynamic> json) {
    if (json['events'] is! List) {
      throw const FormatException('Missing history events');
    }
    return ConformanceHistoryPage(
      events: listOf(json['events'], ConformanceHistoryEvent.fromJson),
      nextPageToken: json['next_page_token'] as String?,
    );
  }
}
