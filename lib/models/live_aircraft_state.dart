/// Current connectivity and independently sampled telemetry for one aircraft.
///
/// The API deliberately does not merge MAVLink messages into a synthetic sample:
/// every telemetry group retains the time at which that message was observed.
class AircraftLiveState {
  const AircraftLiveState({
    required this.aircraftId,
    this.operatorId,
    this.agentId,
    required this.connection,
    required this.telemetry,
  });

  final String aircraftId;
  final String? operatorId;
  final String? agentId;
  final AircraftConnectionState connection;
  final AircraftTelemetryState telemetry;

  factory AircraftLiveState.fromJson(Map<String, dynamic> json) {
    return AircraftLiveState(
      aircraftId: _string(json['aircraft_id']),
      operatorId: _nullableString(json['operator_id']),
      agentId: _nullableString(json['agent_id']),
      connection: AircraftConnectionState.fromJson(_map(json['connection'])),
      telemetry: AircraftTelemetryState.fromJson(_map(json['telemetry'])),
    );
  }
}

class AircraftConnectionState {
  const AircraftConnectionState({
    required this.aircraftId,
    this.operatorId,
    this.agentId,
    this.relayId,
    required this.connected,
    required this.status,
    this.lastConnectedAt,
    this.lastHeartbeatAt,
    this.placementLastUpdatedAt,
  });

  final String aircraftId;
  final String? operatorId;
  final String? agentId;
  final String? relayId;
  final bool connected;
  final String status;
  final DateTime? lastConnectedAt;
  final DateTime? lastHeartbeatAt;
  final DateTime? placementLastUpdatedAt;

  factory AircraftConnectionState.fromJson(Map<String, dynamic> json) {
    return AircraftConnectionState(
      aircraftId: _string(json['aircraft_id']),
      operatorId: _nullableString(json['operator_id']),
      agentId: _nullableString(json['agent_id']),
      relayId: _nullableString(json['relay_id']),
      connected: _bool(json['connected']),
      status: _string(json['connection_status'], fallback: 'unavailable'),
      lastConnectedAt: _date(json['last_connected_at']),
      lastHeartbeatAt: _date(json['last_heartbeat_at']),
      placementLastUpdatedAt: _date(json['placement_last_updated_at']),
    );
  }
}

class AircraftTelemetryState {
  const AircraftTelemetryState({
    required this.status,
    this.lastObservedAt,
    this.position,
    this.battery,
    this.vehicle,
    this.system,
    this.hud,
    this.extendedState,
    this.gps,
  });

  final String status;
  final DateTime? lastObservedAt;
  final PositionTelemetry? position;
  final BatteryTelemetry? battery;
  final VehicleTelemetry? vehicle;
  final SystemTelemetry? system;
  final HudTelemetry? hud;
  final ExtendedStateTelemetry? extendedState;
  final GpsTelemetry? gps;

  factory AircraftTelemetryState.fromJson(Map<String, dynamic> json) {
    return AircraftTelemetryState(
      status: _string(json['status'], fallback: 'unavailable'),
      lastObservedAt: _date(json['last_observed_at']),
      position: _optional(json['position'], PositionTelemetry.fromJson),
      battery: _optional(json['battery'], BatteryTelemetry.fromJson),
      vehicle: _optional(json['vehicle'], VehicleTelemetry.fromJson),
      system: _optional(json['system'], SystemTelemetry.fromJson),
      hud: _optional(json['hud'], HudTelemetry.fromJson),
      extendedState: _optional(
        json['extended_state'],
        ExtendedStateTelemetry.fromJson,
      ),
      gps: _optional(json['gps'], GpsTelemetry.fromJson),
    );
  }
}

class TelemetryGroup {
  const TelemetryGroup({
    required this.status,
    required this.recordedAt,
    this.frameId,
    this.relayId,
    this.sessionId,
    this.timestampSource,
  });

  final String status;
  final DateTime recordedAt;
  final String? frameId;
  final String? relayId;
  final String? sessionId;
  final String? timestampSource;
}

class PositionTelemetry extends TelemetryGroup {
  const PositionTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    required this.latitudeDeg,
    required this.longitudeDeg,
    this.altitudeMslM,
    this.relativeAltitudeM,
    this.velocityNorthMps,
    this.velocityEastMps,
    this.velocityDownMps,
    this.groundspeedMps,
    this.headingDeg,
  });

  final double latitudeDeg;
  final double longitudeDeg;
  final double? altitudeMslM;
  final double? relativeAltitudeM;
  final double? velocityNorthMps;
  final double? velocityEastMps;
  final double? velocityDownMps;
  final double? groundspeedMps;
  final double? headingDeg;

  factory PositionTelemetry.fromJson(Map<String, dynamic> json) {
    return PositionTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      latitudeDeg: _double(json['latitude_deg']),
      longitudeDeg: _double(json['longitude_deg']),
      altitudeMslM: _nullableDouble(json['altitude_msl_m']),
      relativeAltitudeM: _nullableDouble(json['relative_altitude_m']),
      velocityNorthMps: _nullableDouble(json['velocity_north_mps']),
      velocityEastMps: _nullableDouble(json['velocity_east_mps']),
      velocityDownMps: _nullableDouble(json['velocity_down_mps']),
      groundspeedMps: _nullableDouble(json['groundspeed_mps']),
      headingDeg: _nullableDouble(json['heading_deg']),
    );
  }
}

class BatteryTelemetry extends TelemetryGroup {
  const BatteryTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    required this.batteryId,
    this.batteryFunction,
    this.batteryType,
    this.batteryChargeState,
    this.batteryMode,
    this.temperatureC,
    this.voltageV,
    this.currentA,
    this.consumedMah,
    this.consumedWh,
    this.remainingPct,
    this.timeRemainingS,
  });

  final int batteryId;
  final String? batteryFunction;
  final String? batteryType;
  final String? batteryChargeState;
  final String? batteryMode;
  final double? temperatureC;
  final double? voltageV;
  final double? currentA;
  final int? consumedMah;
  final double? consumedWh;
  final double? remainingPct;
  final int? timeRemainingS;

  factory BatteryTelemetry.fromJson(Map<String, dynamic> json) {
    return BatteryTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      batteryId: _int(json['battery_id']),
      batteryFunction: _nullableString(json['battery_function']),
      batteryType: _nullableString(json['battery_type']),
      batteryChargeState: _nullableString(json['battery_charge_state']),
      batteryMode: _nullableString(json['battery_mode']),
      temperatureC: _nullableDouble(json['battery_temperature_c']),
      voltageV: _nullableDouble(json['battery_voltage_v']),
      currentA: _nullableDouble(json['battery_current_a']),
      consumedMah: _nullableInt(json['battery_consumed_mah']),
      consumedWh: _nullableDouble(json['battery_consumed_wh']),
      remainingPct: _nullableDouble(json['battery_remaining_pct']),
      timeRemainingS: _nullableInt(json['battery_time_remaining_s']),
    );
  }
}

class VehicleTelemetry extends TelemetryGroup {
  const VehicleTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    this.vehicleType,
    this.autopilotType,
    this.baseMode,
    this.customMode,
    this.systemStatus,
    this.mavlinkVersion,
  });

  final String? vehicleType;
  final String? autopilotType;
  final String? baseMode;
  final int? customMode;
  final String? systemStatus;
  final int? mavlinkVersion;

  bool? get armed {
    final mode = baseMode;
    if (mode == null) return null;
    return mode.toLowerCase().contains('safety_armed');
  }

  factory VehicleTelemetry.fromJson(Map<String, dynamic> json) {
    return VehicleTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      vehicleType: _nullableString(json['vehicle_type']),
      autopilotType: _nullableString(json['autopilot_type']),
      baseMode: _nullableString(json['base_mode']),
      customMode: _nullableInt(json['custom_mode']),
      systemStatus: _nullableString(json['system_status']),
      mavlinkVersion: _nullableInt(json['mavlink_version']),
    );
  }
}

class SystemTelemetry extends TelemetryGroup {
  const SystemTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    this.mainloopLoadPct,
    this.communicationDropRatePct,
    this.communicationErrorCount,
    this.autopilotErrorCount1,
    this.autopilotErrorCount2,
    this.autopilotErrorCount3,
    this.autopilotErrorCount4,
    this.sensorsPresent,
    this.sensorsEnabled,
    this.sensorsHealth,
    this.sensorsPresentExtended,
    this.sensorsEnabledExtended,
    this.sensorsHealthExtended,
  });

  final double? mainloopLoadPct;
  final double? communicationDropRatePct;
  final int? communicationErrorCount;
  final int? autopilotErrorCount1;
  final int? autopilotErrorCount2;
  final int? autopilotErrorCount3;
  final int? autopilotErrorCount4;
  final String? sensorsPresent;
  final String? sensorsEnabled;
  final String? sensorsHealth;
  final String? sensorsPresentExtended;
  final String? sensorsEnabledExtended;
  final String? sensorsHealthExtended;

  factory SystemTelemetry.fromJson(Map<String, dynamic> json) {
    return SystemTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      mainloopLoadPct: _nullableDouble(json['mainloop_load_pct']),
      communicationDropRatePct: _nullableDouble(
        json['communication_drop_rate_pct'],
      ),
      communicationErrorCount: _nullableInt(json['communication_error_count']),
      autopilotErrorCount1: _nullableInt(json['autopilot_error_count_1']),
      autopilotErrorCount2: _nullableInt(json['autopilot_error_count_2']),
      autopilotErrorCount3: _nullableInt(json['autopilot_error_count_3']),
      autopilotErrorCount4: _nullableInt(json['autopilot_error_count_4']),
      sensorsPresent: _nullableString(json['sensors_present']),
      sensorsEnabled: _nullableString(json['sensors_enabled']),
      sensorsHealth: _nullableString(json['sensors_health']),
      sensorsPresentExtended: _nullableString(json['sensors_present_extended']),
      sensorsEnabledExtended: _nullableString(json['sensors_enabled_extended']),
      sensorsHealthExtended: _nullableString(json['sensors_health_extended']),
    );
  }
}

class HudTelemetry extends TelemetryGroup {
  const HudTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    this.airspeedMps,
    this.groundspeedMps,
    this.headingDeg,
    this.throttlePct,
    this.altitudeMslM,
    this.climbRateMps,
  });

  final double? airspeedMps;
  final double? groundspeedMps;
  final double? headingDeg;
  final double? throttlePct;
  final double? altitudeMslM;
  final double? climbRateMps;

  factory HudTelemetry.fromJson(Map<String, dynamic> json) {
    return HudTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      airspeedMps: _nullableDouble(json['airspeed_mps']),
      groundspeedMps: _nullableDouble(json['groundspeed_mps']),
      headingDeg: _nullableDouble(json['heading_deg']),
      throttlePct: _nullableDouble(json['throttle_pct']),
      altitudeMslM: _nullableDouble(json['altitude_msl_m']),
      climbRateMps: _nullableDouble(json['climb_rate_mps']),
    );
  }
}

class ExtendedStateTelemetry extends TelemetryGroup {
  const ExtendedStateTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    this.vtolState,
    this.landedState,
  });

  final String? vtolState;
  final String? landedState;

  factory ExtendedStateTelemetry.fromJson(Map<String, dynamic> json) {
    return ExtendedStateTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      vtolState: _nullableString(json['vtol_state']),
      landedState: _nullableString(json['landed_state']),
    );
  }
}

class GpsTelemetry extends TelemetryGroup {
  const GpsTelemetry({
    required super.status,
    required super.recordedAt,
    super.frameId,
    super.relayId,
    super.sessionId,
    super.timestampSource,
    this.fixType,
    this.latitudeDeg,
    this.longitudeDeg,
    this.altitudeMslM,
    this.altitudeEllipsoidM,
    this.hdop,
    this.vdop,
    this.groundspeedMps,
    this.courseOverGroundDeg,
    this.satellitesVisible,
    this.horizontalAccuracyM,
    this.verticalAccuracyM,
    this.speedAccuracyMps,
    this.headingAccuracyDeg,
    this.yawDeg,
  });

  final String? fixType;
  final double? latitudeDeg;
  final double? longitudeDeg;
  final double? altitudeMslM;
  final double? altitudeEllipsoidM;
  final double? hdop;
  final double? vdop;
  final double? groundspeedMps;
  final double? courseOverGroundDeg;
  final int? satellitesVisible;
  final double? horizontalAccuracyM;
  final double? verticalAccuracyM;
  final double? speedAccuracyMps;
  final double? headingAccuracyDeg;
  final double? yawDeg;

  factory GpsTelemetry.fromJson(Map<String, dynamic> json) {
    return GpsTelemetry(
      status: _groupStatus(json),
      recordedAt: _requiredDate(json['recorded_at']),
      frameId: _nullableString(json['frame_id']),
      relayId: _nullableString(json['relay_id']),
      sessionId: _nullableString(json['session_id']),
      timestampSource: _nullableString(json['timestamp_source']),
      fixType: _nullableString(json['gps_fix_type']),
      latitudeDeg: _nullableDouble(json['gps_latitude_deg']),
      longitudeDeg: _nullableDouble(json['gps_longitude_deg']),
      altitudeMslM: _nullableDouble(json['gps_altitude_msl_m']),
      altitudeEllipsoidM: _nullableDouble(json['gps_altitude_ellipsoid_m']),
      hdop: _nullableDouble(json['gps_hdop']),
      vdop: _nullableDouble(json['gps_vdop']),
      groundspeedMps: _nullableDouble(json['gps_groundspeed_mps']),
      courseOverGroundDeg: _nullableDouble(json['gps_course_over_ground_deg']),
      satellitesVisible: _nullableInt(json['gps_satellites_visible']),
      horizontalAccuracyM: _nullableDouble(json['gps_horizontal_accuracy_m']),
      verticalAccuracyM: _nullableDouble(json['gps_vertical_accuracy_m']),
      speedAccuracyMps: _nullableDouble(json['gps_speed_accuracy_mps']),
      headingAccuracyDeg: _nullableDouble(json['gps_heading_accuracy_deg']),
      yawDeg: _nullableDouble(json['gps_yaw_deg']),
    );
  }
}

String _groupStatus(Map<String, dynamic> json) =>
    _string(json['status'], fallback: 'stale');

T? _optional<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  return value is Map<String, dynamic> ? parse(value) : null;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : value?.toString() ?? fallback;

String? _nullableString(Object? value) {
  final result = _string(value);
  return result.isEmpty ? null : result;
}

bool _bool(Object? value) => value is bool ? value : false;

int _int(Object? value) {
  if (value is num) return value.toInt();
  throw const FormatException('Expected a required integer telemetry field.');
}

int? _nullableInt(Object? value) => value is num ? value.toInt() : null;

double _double(Object? value) {
  if (value is num) return value.toDouble();
  throw const FormatException('Expected a required numeric telemetry field.');
}

double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

DateTime _requiredDate(Object? value) {
  final result = _date(value);
  if (result != null) return result;
  throw const FormatException('Expected a valid recorded_at timestamp.');
}
