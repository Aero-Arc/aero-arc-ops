import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/aero_arc_models.dart';
import '../models/command.dart';
import '../models/conformance_history.dart';

class AeroArcApiException implements Exception {
  const AeroArcApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AeroArcApiClient {
  AeroArcApiClient({
    http.Client? httpClient,
    Uri? baseUri,
    String? missionControlToken,
  }) : _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse(_defaultBaseUrl),
       _missionControlToken =
           missionControlToken ?? _defaultMissionControlToken;

  static const _defaultBaseUrl = String.fromEnvironment(
    'AERO_ARC_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  // Local development convenience only. Production authentication must be
  // supplied by the deployment environment's identity integration.
  static const _defaultMissionControlToken = String.fromEnvironment(
    'AERO_ARC_MISSION_DEPLOYMENT_TOKEN',
  );

  final http.Client _http;
  final Uri _baseUri;
  final String _missionControlToken;

  bool get hasLocalMissionControlToken =>
      _missionControlToken.trim().isNotEmpty;

  Future<OverviewDashboard> overview() =>
      _get('/api/v1/overview', OverviewDashboard.fromJson);
  Future<AircraftListResponse> aircraft() =>
      _get('/api/v1/aircraft', AircraftListResponse.fromJson);
  Future<AircraftLiveState> getAircraftState(String aircraftId) =>
      _get('/api/v1/aircraft/$aircraftId/state', AircraftLiveState.fromJson);
  Future<OperationsDashboard> operations() =>
      _get('/api/v1/operations', OperationsDashboard.fromJson);
  Future<PreflightDashboard> preflight() =>
      _get('/api/v1/preflight', PreflightDashboard.fromJson);
  Future<ConformanceDashboard> conformance() =>
      _get('/api/v1/conformance', ConformanceDashboard.fromJson);
  Future<ConformanceHistoryPage> conformanceHistory(
    String intentId, {
    int generation = 0,
    DateTime? from,
    DateTime? until,
    int pageSize = 50,
    String? pageToken,
  }) => _get(
    '/api/v1/operational-intents/${Uri.encodeComponent(intentId)}/conformance/events',
    ConformanceHistoryPage.fromJson,
    queryParameters: {
      'generation': '$generation',
      'page_size': '$pageSize',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (until != null) 'until': until.toUtc().toIso8601String(),
      if (pageToken != null && pageToken.isNotEmpty) 'page_token': pageToken,
    },
  );
  Future<ConformanceEvaluation> evaluateTelemetry(TelemetrySample sample) =>
      _post(
        '/api/v1/telemetry',
        ConformanceEvaluation.fromJson,
        body: sample.toJson(),
      );
  Future<MaintenanceDashboard> maintenance() =>
      _get('/api/v1/maintenance', MaintenanceDashboard.fromJson);
  Future<RecordsDashboard> records() =>
      _get('/api/v1/records', RecordsDashboard.fromJson);
  Future<AircraftMapView> getAircraftMapView(
    String aircraftId, {
    int limit = 1000,
  }) {
    return _get(
      '/api/v1/aircraft/$aircraftId/map',
      AircraftMapView.fromJson,
      queryParameters: {'limit': '$limit'},
    );
  }

  Future<OperationalIntent> createOperationalIntent(
    CreateOperationalIntentRequest request,
  ) {
    return _post(
      '/api/v1/operational-intents',
      OperationalIntent.fromJson,
      body: request.toJson(),
    );
  }

  Future<OperationalVolume> addOperationalIntentVolume(
    String intentId,
    AddOperationalVolumeRequest request,
  ) {
    return _post(
      '/api/v1/operational-intents/$intentId/volumes',
      OperationalVolume.fromJson,
      body: request.toJson(),
    );
  }

  Future<ModifyOperationalIntentResult> modifyOperationalIntent(
    String intentId,
    ModifyOperationalIntentRequest request,
  ) {
    return _post(
      '/api/v1/operational-intents/$intentId/modify',
      ModifyOperationalIntentResult.fromJson,
      body: request.toJson(),
    );
  }

  Future<OperationalIntent> submitOperationalIntent(String intentId) {
    return _post(
      '/api/v1/operational-intents/$intentId/submit',
      OperationalIntent.fromJson,
    );
  }

  Future<PreflightEvaluationResult> evaluateOperationalIntentPreflight(
    String intentId,
  ) {
    return _post(
      '/api/v1/operational-intents/$intentId/preflight/evaluate',
      PreflightEvaluationResult.fromJson,
    );
  }

  Future<DeconflictionResult> checkOperationalIntentDeconfliction(
    String intentId,
  ) {
    return _post(
      '/api/v1/operational-intents/$intentId/deconfliction/check',
      DeconflictionResult.fromJson,
    );
  }

  Future<ConflictFindingsResponse> getOperationalIntentConflicts(
    String intentId,
  ) {
    return _get(
      '/api/v1/operational-intents/$intentId/conflicts',
      ConflictFindingsResponse.fromJson,
    );
  }

  Future<OperationalIntent> acceptOperationalIntent(String intentId) {
    return _post(
      '/api/v1/operational-intents/$intentId/accept',
      OperationalIntent.fromJson,
    );
  }

  Future<OperationalIntent> activateOperationalIntent(String intentId) {
    return _post(
      '/api/v1/operational-intents/$intentId/activate',
      OperationalIntent.fromJson,
    );
  }

  Future<FlightRecord> createPlannedFlight(
    String intentId,
    CreateFlightRequest request,
  ) {
    return _post(
      '/api/v1/operational-intents/$intentId/flights',
      FlightRecord.fromJson,
      body: request.toJson(),
    );
  }

  Future<FlightListResponse> listAircraftFlights(String aircraftId) =>
      _get('/api/v1/aircraft/$aircraftId/flights', FlightListResponse.fromJson);

  Future<MissionImportResult> importMission({
    required String flightId,
    required String aircraftId,
    required String intentId,
    required int intentVersion,
    required String source,
    required String idempotencyKey,
  }) async {
    return await _post(
      '/api/v1/flights/$flightId/missions/import',
      MissionImportResult.fromJson,
      headers: _missionControlHeaders(idempotencyKey: idempotencyKey),
      body: {
        'source_format': 'qgc_wpl_110',
        'source': source,
        'aircraft_id': aircraftId,
        'intent_id': intentId,
        'intent_version': intentVersion,
      },
    );
  }

  /// Restores durable commands after navigation, reload, or a lost submission response.
  Future<List<FlightCommand>> flightCommands(String flightId) => _get(
    '/api/v1/flights/${Uri.encodeComponent(flightId)}/commands',
    (json) => (json['commands'] as List)
        .map((c) => FlightCommand.fromJson(c as Map<String, dynamic>))
        .toList(growable: false),
    headers: _missionControlHeaders(),
  );

  /// Submits one approved operation with a stable key retained across retries.
  Future<FlightCommand> submitFlightCommand({
    required String flightId,
    required String type,
    required String idempotencyKey,
    Mission? mission,
  }) => _post(
    '/api/v1/flights/${Uri.encodeComponent(flightId)}/commands',
    FlightCommand.fromJson,
    headers: _missionControlHeaders(idempotencyKey: idempotencyKey),
    body: {
      'type': type,
      if (mission != null) ...{
        'mission_id': mission.id,
        'mission_digest': mission.missionDigest,
      },
    },
  );

  /// Reconciles existing authority; this never creates a replacement command.
  Future<FlightCommand> reconcileFlightCommand(
    String flightId,
    String commandId,
  ) => _postEmpty(
    '/api/v1/flights/${Uri.encodeComponent(flightId)}/commands/${Uri.encodeComponent(commandId)}/reconcile',
    FlightCommand.fromJson,
    headers: _missionControlHeaders(),
  );

  Future<Mission> getCurrentMission(String flightId) =>
      _get('/api/v1/flights/$flightId/missions/current', Mission.fromJson);

  Future<MissionDeploymentResponse> deployMission({
    required Mission mission,
    required String idempotencyKey,
  }) async {
    if (!_lowercaseSha256.hasMatch(mission.missionDigest)) {
      throw const AeroArcApiException(
        'Mission deployment requires a lowercase SHA-256 mission digest.',
      );
    }
    final headers = _missionControlHeaders(
      idempotencyKey: idempotencyKey,
      missionDigest: mission.missionDigest,
    );
    return await _postEmpty(
      '/api/v1/flights/${mission.flightId}/missions/${mission.id}/deploy',
      MissionDeploymentResponse.fromJson,
      headers: headers,
    );
  }

  Future<MissionDeployment> getMissionDeployment({
    required String flightId,
    required String deploymentId,
  }) async {
    return await _get(
      '/api/v1/flights/$flightId/mission-deployments/$deploymentId',
      MissionDeployment.fromJson,
      headers: _missionControlHeaders(),
    );
  }

  Future<MissionDeployment> getCurrentMissionDeployment(String flightId) {
    return _get(
      '/api/v1/flights/$flightId/mission-deployments/current',
      MissionDeployment.fromJson,
      headers: _missionControlHeaders(),
    );
  }

  Future<MissionDeploymentResponse> reconcileMissionDeployment({
    required String flightId,
    required String deploymentId,
  }) {
    return _postEmpty(
      '/api/v1/flights/$flightId/mission-deployments/$deploymentId/reconcile',
      MissionDeploymentResponse.fromJson,
      headers: _missionControlHeaders(),
    );
  }

  Map<String, String> _missionControlHeaders({
    String? idempotencyKey,
    String? missionDigest,
  }) {
    final token = _missionControlToken.trim();
    if (token.isEmpty) {
      throw const AeroArcApiException(
        'Mission control is unavailable: no local development credential is configured.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Idempotency-Key': ?idempotencyKey,
      if (missionDigest != null) 'If-Match': '"$missionDigest"',
    };
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _http.get(
      _baseUri.replace(path: path, queryParameters: queryParameters),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AeroArcApiException(
        'API ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AeroArcApiException(
        'API returned an unexpected JSON payload.',
      );
    }
    return parse(decoded);
  }

  Future<T> _postEmpty<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    required Map<String, String> headers,
  }) async {
    final response = await _http.post(
      _baseUri.replace(path: path),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AeroArcApiException(
        'API ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AeroArcApiException(
        'API returned an unexpected JSON payload.',
      );
    }
    return parse(decoded);
  }

  Future<T> _post<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final response = await _http.post(
      _baseUri.replace(path: path),
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AeroArcApiException(
        'API ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AeroArcApiException(
        'API returned an unexpected JSON payload.',
      );
    }
    return parse(decoded);
  }
}

final RegExp _lowercaseSha256 = RegExp(r'^[0-9a-f]{64}$');
