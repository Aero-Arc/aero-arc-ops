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
    this.plannedStartAt,
    this.plannedEndAt,
  });
  final String id, assignmentId, intentId, aircraftId, flightId, incidentId;
  final String transition, violationType, frameId;
  final int generation, intentVersion, revision;
  final DateTime observedAt;
  final double? deviationM;
  final DateTime? plannedStartAt, plannedEndAt;

  bool get isTemporal => violationType == 'temporal_deviation';
  String get measurementLabel {
    if (!isTemporal) {
      return deviationM == null
          ? 'Distance not recorded'
          : '${deviationM!.toStringAsFixed(1)} m';
    }
    final end = plannedEndAt;
    final start = plannedStartAt;
    if (end != null && !observedAt.isBefore(end)) {
      return '${_elapsed(observedAt.difference(end))} past planned end';
    }
    if (start != null && observedAt.isBefore(start)) {
      return '${_elapsed(start.difference(observedAt))} before planned start';
    }
    return start == null || end == null
        ? 'Timing details unavailable'
        : 'Outside a scheduled time window';
  }

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
        plannedStartAt: asDate(json['planned_start_at']),
        plannedEndAt: asDate(json['planned_end_at']),
      );
}

String _elapsed(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 1) return '<1 sec';
  if (seconds < 60) return '$seconds sec';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
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
