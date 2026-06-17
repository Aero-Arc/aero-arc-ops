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

  Future<T> _get<T>(String path, T Function(Map<String, dynamic>) parse) async {
    final response = await _http.get(_baseUri.replace(path: path));
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
}
