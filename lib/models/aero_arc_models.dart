class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.value,
    this.detail,
    this.status,
  });

  final String label;
  final String value;
  final String? detail;
  final String? status;

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      label: asString(json['label']),
      value: asString(json['value']),
      detail: asNullableString(json['detail']),
      status: asNullableString(json['status']),
    );
  }
}

class OverviewDashboard {
  const OverviewDashboard({
    required this.metrics,
    required this.aircraft,
    required this.operationalIntents,
    required this.evidenceRecords,
    required this.reportabilityReviews,
  });

  final List<DashboardMetric> metrics;
  final List<AircraftDashboard> aircraft;
  final List<OperationalIntent> operationalIntents;
  final List<EvidenceRecord> evidenceRecords;
  final List<ReportabilityReview> reportabilityReviews;

  factory OverviewDashboard.fromJson(Map<String, dynamic> json) {
    return OverviewDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      aircraft: listOf(json['aircraft'], AircraftDashboard.fromJson),
      operationalIntents: listOf(
        json['operational_intents'],
        OperationalIntent.fromJson,
      ),
      evidenceRecords: listOf(
        json['evidence_records'],
        EvidenceRecord.fromJson,
      ),
      reportabilityReviews: listOf(
        json['reportability_reviews'],
        ReportabilityReview.fromJson,
      ),
    );
  }
}

class OperationsDashboard {
  const OperationsDashboard({
    required this.metrics,
    required this.operationalIntents,
    required this.conformance,
  });

  final List<DashboardMetric> metrics;
  final List<OperationalIntent> operationalIntents;
  final List<ConformanceSummary> conformance;

  factory OperationsDashboard.fromJson(Map<String, dynamic> json) {
    return OperationsDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      operationalIntents: listOf(
        json['operational_intents'],
        OperationalIntent.fromJson,
      ),
      conformance: listOf(json['conformance'], ConformanceSummary.fromJson),
    );
  }
}

class PreflightDashboard {
  const PreflightDashboard({required this.metrics, required this.checks});

  final List<DashboardMetric> metrics;
  final List<PreflightCheck> checks;

  factory PreflightDashboard.fromJson(Map<String, dynamic> json) {
    return PreflightDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      checks: listOf(json['checks'], PreflightCheck.fromJson),
    );
  }
}

class ConformanceDashboard {
  const ConformanceDashboard({
    required this.metrics,
    required this.summaries,
    required this.events,
  });

  final List<DashboardMetric> metrics;
  final List<ConformanceSummary> summaries;
  final List<ConformanceEvent> events;

  factory ConformanceDashboard.fromJson(Map<String, dynamic> json) {
    return ConformanceDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      summaries: listOf(json['summaries'], ConformanceSummary.fromJson),
      events: listOf(json['events'], ConformanceEvent.fromJson),
    );
  }
}

class MaintenanceDashboard {
  const MaintenanceDashboard({
    required this.metrics,
    required this.events,
    required this.batteries,
  });

  final List<DashboardMetric> metrics;
  final List<MaintenanceEvent> events;
  final List<Battery> batteries;

  factory MaintenanceDashboard.fromJson(Map<String, dynamic> json) {
    return MaintenanceDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      events: listOf(json['events'], MaintenanceEvent.fromJson),
      batteries: listOf(json['batteries'], Battery.fromJson),
    );
  }
}

class RecordsDashboard {
  const RecordsDashboard({
    required this.metrics,
    required this.evidenceRecords,
    required this.reportabilityReviews,
  });

  final List<DashboardMetric> metrics;
  final List<EvidenceRecord> evidenceRecords;
  final List<ReportabilityReview> reportabilityReviews;

  factory RecordsDashboard.fromJson(Map<String, dynamic> json) {
    return RecordsDashboard(
      metrics: listOf(json['metrics'], DashboardMetric.fromJson),
      evidenceRecords: listOf(
        json['evidence_records'],
        EvidenceRecord.fromJson,
      ),
      reportabilityReviews: listOf(
        json['reportability_reviews'],
        ReportabilityReview.fromJson,
      ),
    );
  }
}

class AircraftListResponse {
  const AircraftListResponse({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  factory AircraftListResponse.fromJson(Map<String, dynamic> json) {
    return AircraftListResponse(
      aircraft: listOf(json['aircraft'], AircraftDashboard.fromJson),
    );
  }
}

class AircraftDashboard {
  const AircraftDashboard({
    required this.aircraft,
    this.activeBattery,
    required this.maintenanceEvents,
    this.latestTelemetry,
    this.liveState,
    required this.liveStateAvailable,
    required this.readiness,
  });

  final Aircraft aircraft;
  final Battery? activeBattery;
  final List<MaintenanceEvent> maintenanceEvents;
  final TelemetrySample? latestTelemetry;
  final LiveAircraftState? liveState;
  final bool liveStateAvailable;
  final Readiness readiness;

  factory AircraftDashboard.fromJson(Map<String, dynamic> json) {
    return AircraftDashboard(
      aircraft: Aircraft.fromJson(asMap(json['aircraft'])),
      activeBattery: optional(json['active_battery'], Battery.fromJson),
      maintenanceEvents: listOf(
        json['maintenance_events'],
        MaintenanceEvent.fromJson,
      ),
      latestTelemetry: optional(
        json['latest_telemetry'],
        TelemetrySample.fromJson,
      ),
      liveState: optional(json['live_state'], LiveAircraftState.fromJson),
      liveStateAvailable: asBool(json['live_state_available']),
      readiness: Readiness.fromJson(asMap(json['readiness'])),
    );
  }
}

class AircraftMapView {
  const AircraftMapView({
    required this.aircraft,
    this.liveState,
    required this.liveStateAvailable,
    this.latestTelemetry,
    required this.replaySamples,
    this.activeIntent,
    required this.operationalVolumes,
    this.conformanceSummary,
    required this.conformanceEvents,
  });

  final Aircraft aircraft;
  final LiveAircraftState? liveState;
  final bool liveStateAvailable;
  final TelemetrySample? latestTelemetry;
  final List<TelemetrySample> replaySamples;
  final OperationalIntent? activeIntent;
  final List<OperationalVolume> operationalVolumes;
  final ConformanceSummary? conformanceSummary;
  final List<ConformanceEvent> conformanceEvents;

  factory AircraftMapView.fromJson(Map<String, dynamic> json) {
    return AircraftMapView(
      aircraft: Aircraft.fromJson(asMap(json['aircraft'])),
      liveState: optional(json['live_state'], LiveAircraftState.fromJson),
      liveStateAvailable: asBool(json['live_state_available']),
      latestTelemetry: optional(
        json['latest_telemetry'],
        TelemetrySample.fromJson,
      ),
      replaySamples: listOf(json['replay_samples'], TelemetrySample.fromJson),
      activeIntent: optional(json['active_intent'], OperationalIntent.fromJson),
      operationalVolumes: listOf(
        json['operational_volumes'],
        OperationalVolume.fromJson,
      ),
      conformanceSummary: optional(
        json['conformance_summary'],
        ConformanceSummary.fromJson,
      ),
      conformanceEvents: listOf(
        json['conformance_events'],
        ConformanceEvent.fromJson,
      ),
    );
  }
}

class Aircraft {
  const Aircraft({
    required this.id,
    this.operatorId,
    this.agentId,
    required this.tailNumber,
    this.registration,
    this.serialNumber,
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.status,
    required this.acceptanceStatus,
    this.remoteIdSerial,
    required this.remoteIdStatus,
    this.configVersion,
    this.softwareVersion,
    this.hardwareVersion,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? operatorId;
  final String? agentId;
  final String tailNumber;
  final String? registration;
  final String? serialNumber;
  final String name;
  final String model;
  final String manufacturer;
  final String status;
  final String acceptanceStatus;
  final String? remoteIdSerial;
  final String remoteIdStatus;
  final String? configVersion;
  final String? softwareVersion;
  final String? hardwareVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => firstNonEmpty([name, tailNumber, registration, id]);

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    return Aircraft(
      id: asString(json['id']),
      operatorId: asNullableString(json['operator_id']),
      agentId: asNullableString(json['agent_id']),
      tailNumber: asString(json['tail_number']),
      registration: asNullableString(json['registration']),
      serialNumber: asNullableString(json['serial_number']),
      name: asString(json['name']),
      model: asString(json['model']),
      manufacturer: asString(json['manufacturer']),
      status: asString(json['status']),
      acceptanceStatus: asString(json['acceptance_status']),
      remoteIdSerial: asNullableString(json['remote_id_serial']),
      remoteIdStatus: asString(json['remote_id_status']),
      configVersion: asNullableString(json['config_version']),
      softwareVersion: asNullableString(json['software_version']),
      hardwareVersion: asNullableString(json['hardware_version']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class Battery {
  const Battery({
    required this.id,
    this.operatorId,
    required this.serialNumber,
    required this.model,
    this.stateOfHealth,
    required this.cycleCount,
    required this.status,
    this.manufacturedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? operatorId;
  final String serialNumber;
  final String model;
  final double? stateOfHealth;
  final int cycleCount;
  final String status;
  final DateTime? manufacturedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Battery.fromJson(Map<String, dynamic> json) {
    return Battery(
      id: asString(json['id']),
      operatorId: asNullableString(json['operator_id']),
      serialNumber: asString(json['serial_number']),
      model: asString(json['model']),
      stateOfHealth: asNullableDouble(json['state_of_health']),
      cycleCount: asInt(json['cycle_count']),
      status: asString(json['status']),
      manufacturedAt: asDate(json['manufactured_at']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class MaintenanceEvent {
  const MaintenanceEvent({
    required this.id,
    this.operatorId,
    required this.aircraftId,
    this.intentId,
    this.eventType,
    required this.severity,
    required this.status,
    required this.title,
    required this.notes,
    this.owner,
    this.dueAt,
    this.correctiveAction,
    this.openedAt,
    this.resolvedAt,
    this.returnToServiceAt,
    this.returnToServiceBy,
  });

  final String id;
  final String? operatorId;
  final String aircraftId;
  final String? intentId;
  final String? eventType;
  final String severity;
  final String status;
  final String title;
  final String notes;
  final String? owner;
  final DateTime? dueAt;
  final String? correctiveAction;
  final DateTime? openedAt;
  final DateTime? resolvedAt;
  final DateTime? returnToServiceAt;
  final String? returnToServiceBy;

  factory MaintenanceEvent.fromJson(Map<String, dynamic> json) {
    return MaintenanceEvent(
      id: asString(json['id']),
      operatorId: asNullableString(json['operator_id']),
      aircraftId: asString(json['aircraft_id']),
      intentId: asNullableString(json['intent_id']),
      eventType: asNullableString(json['event_type']),
      severity: asString(json['severity']),
      status: asString(json['status']),
      title: asString(json['title']),
      notes: asString(json['notes']),
      owner: asNullableString(json['owner']),
      dueAt: asDate(json['due_at']),
      correctiveAction: asNullableString(json['corrective_action']),
      openedAt: asDate(json['opened_at']),
      resolvedAt: asDate(json['resolved_at']),
      returnToServiceAt: asDate(json['return_to_service_at']),
      returnToServiceBy: asNullableString(json['return_to_service_by']),
    );
  }
}

class TelemetrySample {
  const TelemetrySample({
    required this.id,
    required this.aircraftId,
    this.intentId,
    this.flightId,
    this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.altitudeM,
    required this.velocityMps,
    required this.headingDeg,
    this.batteryPct,
  });

  final String id;
  final String aircraftId;
  final String? intentId;
  final String? flightId;
  final DateTime? recordedAt;
  final double latitude;
  final double longitude;
  final double altitudeM;
  final double velocityMps;
  final double headingDeg;
  final double? batteryPct;

  factory TelemetrySample.fromJson(Map<String, dynamic> json) {
    return TelemetrySample(
      id: asString(json['id']),
      aircraftId: asString(json['aircraft_id']),
      intentId: asNullableString(json['intent_id']),
      flightId: asNullableString(json['flight_id']),
      recordedAt: asDate(json['recorded_at']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      altitudeM: asDouble(json['altitude_m']),
      velocityMps: asDouble(json['velocity_mps']),
      headingDeg: asDouble(json['heading_deg']),
      batteryPct: asNullableDouble(json['battery_pct']),
    );
  }
}

class LiveAircraftState {
  const LiveAircraftState({
    required this.aircraftId,
    this.agentId,
    this.relayId,
    required this.connected,
    this.lastConnectedAt,
    this.lastHeartbeatAt,
    this.placementLastUpdatedAt,
  });

  final String aircraftId;
  final String? agentId;
  final String? relayId;
  final bool connected;
  final DateTime? lastConnectedAt;
  final DateTime? lastHeartbeatAt;
  final DateTime? placementLastUpdatedAt;

  factory LiveAircraftState.fromJson(Map<String, dynamic> json) {
    return LiveAircraftState(
      aircraftId: asString(json['aircraft_id']),
      agentId: asNullableString(json['agent_id']),
      relayId: asNullableString(json['relay_id']),
      connected: asBool(json['connected']),
      lastConnectedAt: asDate(json['last_connected_at']),
      lastHeartbeatAt: asDate(json['last_heartbeat_at']),
      placementLastUpdatedAt: asDate(json['placement_last_updated_at']),
    );
  }
}

class Readiness {
  const Readiness({required this.status, required this.reasons});

  final String status;
  final List<String> reasons;

  factory Readiness.fromJson(Map<String, dynamic> json) {
    return Readiness(
      status: asString(json['status']),
      reasons: stringList(json['reasons']),
    );
  }
}

class OperationalIntent {
  const OperationalIntent({
    required this.id,
    required this.aircraftId,
    this.authorizationId,
    required this.version,
    required this.name,
    required this.summary,
    this.useCase,
    required this.authorizationPath,
    required this.populationCategory,
    required this.status,
    required this.conformanceRequired,
    this.operatingAreaId,
    this.routeSummary,
    this.plannedStartAt,
    this.plannedEndAt,
    this.minAltitudeFtAgl,
    this.maxAltitudeFtAgl,
    this.supervisorId,
    this.flightCoordinatorId,
    this.updatedAt,
  });

  final String id;
  final String aircraftId;
  final String? authorizationId;
  final int version;
  final String name;
  final String summary;
  final String? useCase;
  final String authorizationPath;
  final String populationCategory;
  final String status;
  final bool conformanceRequired;
  final String? operatingAreaId;
  final String? routeSummary;
  final DateTime? plannedStartAt;
  final DateTime? plannedEndAt;
  final double? minAltitudeFtAgl;
  final double? maxAltitudeFtAgl;
  final String? supervisorId;
  final String? flightCoordinatorId;
  final DateTime? updatedAt;

  factory OperationalIntent.fromJson(Map<String, dynamic> json) {
    return OperationalIntent(
      id: asString(json['id']),
      aircraftId: asString(json['aircraft_id']),
      authorizationId: asNullableString(json['authorization_id']),
      version: asInt(json['version']),
      name: asString(json['name']),
      summary: asString(json['summary']),
      useCase: asNullableString(json['use_case']),
      authorizationPath: asString(json['authorization_path']),
      populationCategory: asString(json['population_category']),
      status: asString(json['status']),
      conformanceRequired: asBool(json['conformance_required']),
      operatingAreaId: asNullableString(json['operating_area_id']),
      routeSummary: asNullableString(json['route_summary']),
      plannedStartAt: asDate(json['planned_start_at']),
      plannedEndAt: asDate(json['planned_end_at']),
      minAltitudeFtAgl: asNullableDouble(json['min_altitude_ft_agl']),
      maxAltitudeFtAgl: asNullableDouble(json['max_altitude_ft_agl']),
      supervisorId: asNullableString(json['supervisor_id']),
      flightCoordinatorId: asNullableString(json['flight_coordinator_id']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class OperationalVolume {
  const OperationalVolume({
    required this.id,
    this.operatorId,
    required this.intentId,
    required this.intentVersion,
    required this.sequence,
    this.geometryUri,
    this.geoJson,
    required this.minAltitudeM,
    required this.maxAltitudeM,
    required this.altitudeRef,
    this.startsAt,
    this.endsAt,
    this.bufferMeters,
    this.volumeType,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? operatorId;
  final String intentId;
  final int intentVersion;
  final int sequence;
  final String? geometryUri;
  final String? geoJson;
  final double minAltitudeM;
  final double maxAltitudeM;
  final String altitudeRef;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? bufferMeters;
  final String? volumeType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OperationalVolume.fromJson(Map<String, dynamic> json) {
    return OperationalVolume(
      id: asString(json['id']),
      operatorId: asNullableString(json['operator_id']),
      intentId: asString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      sequence: asInt(json['sequence']),
      geometryUri: asNullableString(json['geometry_uri']),
      geoJson: asNullableString(json['geojson']),
      minAltitudeM: asDouble(json['min_altitude_m']),
      maxAltitudeM: asDouble(json['max_altitude_m']),
      altitudeRef: asString(json['altitude_ref']),
      startsAt: asDate(json['starts_at']),
      endsAt: asDate(json['ends_at']),
      bufferMeters: asNullableDouble(json['buffer_meters']),
      volumeType: asNullableString(json['volume_type']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class PreflightCheck {
  const PreflightCheck({
    required this.id,
    required this.intentId,
    required this.intentVersion,
    this.aircraftId,
    required this.category,
    required this.source,
    required this.status,
    required this.summary,
    this.requirementCode,
    this.ruleVersion,
    required this.blocking,
    this.validUntil,
    this.rawDataUri,
    this.evidenceRecordId,
    this.capturedAt,
  });

  final String id;
  final String intentId;
  final int intentVersion;
  final String? aircraftId;
  final String category;
  final String source;
  final String status;
  final String summary;
  final String? requirementCode;
  final String? ruleVersion;
  final bool blocking;
  final DateTime? validUntil;
  final String? rawDataUri;
  final String? evidenceRecordId;
  final DateTime? capturedAt;

  factory PreflightCheck.fromJson(Map<String, dynamic> json) {
    return PreflightCheck(
      id: asString(json['id']),
      intentId: asString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      aircraftId: asNullableString(json['aircraft_id']),
      category: asString(json['category']),
      source: asString(json['source']),
      status: asString(json['status']),
      summary: asString(json['summary']),
      requirementCode: asNullableString(json['requirement_code']),
      ruleVersion: asNullableString(json['rule_version']),
      blocking: asBool(json['blocking']),
      validUntil: asDate(json['valid_until']),
      rawDataUri: asNullableString(json['raw_data_uri']),
      evidenceRecordId: asNullableString(json['evidence_record_id']),
      capturedAt: asDate(json['captured_at']),
    );
  }
}

class ConformanceSummary {
  const ConformanceSummary({
    required this.id,
    required this.intentId,
    required this.intentVersion,
    this.flightId,
    required this.aircraftId,
    required this.status,
    this.score,
    required this.alertCount,
    required this.reportabilityStatus,
    this.updatedAt,
  });

  final String id;
  final String intentId;
  final int intentVersion;
  final String? flightId;
  final String aircraftId;
  final String status;
  final double? score;
  final int alertCount;
  final String reportabilityStatus;
  final DateTime? updatedAt;

  factory ConformanceSummary.fromJson(Map<String, dynamic> json) {
    return ConformanceSummary(
      id: asString(json['id']),
      intentId: asString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      flightId: asNullableString(json['flight_id']),
      aircraftId: asString(json['aircraft_id']),
      status: asString(json['status']),
      score: asNullableDouble(json['score']),
      alertCount: asInt(json['alert_count']),
      reportabilityStatus: asString(json['reportability_status']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class ConformanceEvent {
  const ConformanceEvent({
    required this.id,
    this.intentId,
    required this.intentVersion,
    this.flightId,
    this.aircraftId,
    required this.severity,
    required this.eventCode,
    this.expectedVolumeId,
    required this.message,
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.altitudeRef,
    this.observedValue,
    this.thresholdValue,
    this.deviationMeters,
    this.deviationSeconds,
    this.occurredAt,
  });

  final String id;
  final String? intentId;
  final int intentVersion;
  final String? flightId;
  final String? aircraftId;
  final String severity;
  final String eventCode;
  final String? expectedVolumeId;
  final String message;
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
  final String? altitudeRef;
  final double? observedValue;
  final double? thresholdValue;
  final double? deviationMeters;
  final double? deviationSeconds;
  final DateTime? occurredAt;

  factory ConformanceEvent.fromJson(Map<String, dynamic> json) {
    return ConformanceEvent(
      id: asString(json['id']),
      intentId: asNullableString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      flightId: asNullableString(json['flight_id']),
      aircraftId: asNullableString(json['aircraft_id']),
      severity: asString(json['severity']),
      eventCode: asString(json['event_code']),
      expectedVolumeId: asNullableString(json['expected_volume_id']),
      message: asString(json['message']),
      latitude: asNullableDouble(json['latitude']),
      longitude: asNullableDouble(json['longitude']),
      altitudeM: asNullableDouble(json['altitude_m']),
      altitudeRef: asNullableString(json['altitude_ref']),
      observedValue: asNullableDouble(json['observed_value']),
      thresholdValue: asNullableDouble(json['threshold_value']),
      deviationMeters: asNullableDouble(json['deviation_meters']),
      deviationSeconds: asNullableDouble(json['deviation_seconds']),
      occurredAt: asDate(json['occurred_at']),
    );
  }
}

class EvidenceRecord {
  const EvidenceRecord({
    required this.id,
    required this.type,
    this.intentId,
    required this.intentVersion,
    this.flightId,
    this.aircraftId,
    required this.status,
    required this.title,
    this.summary,
    this.objectUri,
    this.hash,
    this.hashAlgorithm,
    this.schemaVersion,
    this.generatedBy,
    this.sourceSystem,
    this.retentionUntil,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String? intentId;
  final int intentVersion;
  final String? flightId;
  final String? aircraftId;
  final String status;
  final String title;
  final String? summary;
  final String? objectUri;
  final String? hash;
  final String? hashAlgorithm;
  final String? schemaVersion;
  final String? generatedBy;
  final String? sourceSystem;
  final DateTime? retentionUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory EvidenceRecord.fromJson(Map<String, dynamic> json) {
    return EvidenceRecord(
      id: asString(json['id']),
      type: asString(json['type']),
      intentId: asNullableString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      flightId: asNullableString(json['flight_id']),
      aircraftId: asNullableString(json['aircraft_id']),
      status: asString(json['status']),
      title: asString(json['title']),
      summary: asNullableString(json['summary']),
      objectUri: asNullableString(json['object_uri']),
      hash: asNullableString(json['hash']),
      hashAlgorithm: asNullableString(json['hash_algorithm']),
      schemaVersion: asNullableString(json['schema_version']),
      generatedBy: asNullableString(json['generated_by']),
      sourceSystem: asNullableString(json['source_system']),
      retentionUntil: asDate(json['retention_until']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}

class ReportabilityReview {
  const ReportabilityReview({
    required this.id,
    this.intentId,
    required this.intentVersion,
    this.flightId,
    this.aircraftId,
    required this.trigger,
    required this.status,
    this.decision,
    this.evidenceRecordId,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String? intentId;
  final int intentVersion;
  final String? flightId;
  final String? aircraftId;
  final String trigger;
  final String status;
  final String? decision;
  final String? evidenceRecordId;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory ReportabilityReview.fromJson(Map<String, dynamic> json) {
    return ReportabilityReview(
      id: asString(json['id']),
      intentId: asNullableString(json['intent_id']),
      intentVersion: asInt(json['intent_version']),
      flightId: asNullableString(json['flight_id']),
      aircraftId: asNullableString(json['aircraft_id']),
      trigger: asString(json['trigger']),
      status: asString(json['status']),
      decision: asNullableString(json['decision']),
      evidenceRecordId: asNullableString(json['evidence_record_id']),
      createdAt: asDate(json['created_at']),
      resolvedAt: asDate(json['resolved_at']),
    );
  }
}

String asString(Object? value) => value?.toString() ?? '';
String? asNullableString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

bool asBool(Object? value) => value == true;
int asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(asString(value)) ?? 0;
double asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(asString(value)) ?? 0;
double? asNullableDouble(Object? value) =>
    value == null ? null : asDouble(value);
DateTime? asDate(Object? value) =>
    value == null || value == '' ? null : DateTime.tryParse(asString(value));

Map<String, dynamic> asMap(Object? value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

T? optional<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  return value is Map<String, dynamic> ? parse(value) : null;
}

List<T> listOf<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) parse(item),
  ];
}

List<String> stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) asString(item)];
}

String firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return 'Unknown';
}
