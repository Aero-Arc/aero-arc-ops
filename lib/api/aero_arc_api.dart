import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/aero_arc_models.dart';

class AeroArcApiException implements Exception {
  const AeroArcApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AeroArcApiClient {
  AeroArcApiClient({http.Client? httpClient, Uri? baseUri})
    : _http = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse(_defaultBaseUrl);

  static const _defaultBaseUrl = String.fromEnvironment(
    'AERO_ARC_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  final http.Client _http;
  final Uri _baseUri;

  Future<OverviewDashboard> overview() =>
      _get('/api/v1/overview', OverviewDashboard.fromJson);
  Future<AircraftListResponse> aircraft() =>
      _get('/api/v1/aircraft', AircraftListResponse.fromJson);
  Future<OperationsDashboard> operations() =>
      _get('/api/v1/operations', OperationsDashboard.fromJson);
  Future<PreflightDashboard> preflight() =>
      _get('/api/v1/preflight', PreflightDashboard.fromJson);
  Future<ConformanceDashboard> conformance() =>
      _get('/api/v1/conformance', ConformanceDashboard.fromJson);
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

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _http.get(
      _baseUri.replace(path: path, queryParameters: queryParameters),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AeroArcApiException('API ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
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
  }) async {
    final response = await _http.post(
      _baseUri.replace(path: path),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AeroArcApiException('API ${response.statusCode}: ${response.body}');
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
