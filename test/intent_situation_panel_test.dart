import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aero_arc_web/api/aero_arc_api.dart';
import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/widgets/intent_situation_panel.dart';

OperationalIntent intent(int version) => OperationalIntent.fromJson({
  'id': 'intent-1',
  'aircraft_id': 'aircraft-1',
  'version': version,
  'status': 'active',
  'name': 'Inspection',
});
Map<String, dynamic> mapView(int version) => {
  'aircraft': {'id': 'aircraft-1'},
  'active_intent': {
    'id': 'intent-1',
    'aircraft_id': 'aircraft-1',
    'version': version,
  },
  'operational_volumes': [
    {
      'id': 'volume-$version',
      'intent_id': 'intent-1',
      'intent_version': version,
      'geojson':
          '{"type":"Polygon","coordinates":[[[-97,35],[-97.01,35],[-97.01,35.01],[-97,35]]]}',
    },
  ],
};
Map<String, dynamic> state(String freshness) => {
  'aircraft_id': 'aircraft-1',
  'connection': {'connection_status': 'connected'},
  'telemetry': {
    'status': freshness,
    'position': {
      'status': freshness,
      'recorded_at': '2026-09-26T01:00:00Z',
      'latitude_deg': 35.001,
      'longitude_deg': -97.002,
      'relative_altitude_m': 12,
    },
  },
};
http.Response jsonResponse(Object value) =>
    http.Response(jsonEncode(value), 200);
Widget page(AeroArcApiClient api, {int version = 1}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: IntentSituationPanel(
        api: api,
        intent: intent(version),
        aircraftId: 'aircraft-1',
        renderTiles: false,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'restores saved boundary without passed geometry and preserves stale position identity',
    (tester) async {
      final requests = <String>[];
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          requests.add(request.method);
          return jsonResponse(
            request.url.path.endsWith('/map') ? mapView(1) : state('stale'),
          );
        }),
      );
      await tester.pumpWidget(page(api));
      await tester.pumpAndSettle();
      final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
      expect(layer.polygons.single.points.first.latitude, 35);
      expect(layer.polygons.single.points.first.longitude, -97);
      expect(find.text('Last known aircraft'), findsOneWidget);
      expect(find.text('35.00100, -97.00200'), findsOneWidget);
      expect(requests.every((method) => method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'telemetry outage leaves saved geometry visible and no fresh marker claim',
    (tester) async {
      var failed = false;
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/map')) {
            return jsonResponse(mapView(1));
          }
          if (failed) return http.Response('unavailable', 503);
          return jsonResponse(state('fresh'));
        }),
      );
      await tester.pumpWidget(page(api));
      await tester.pumpAndSettle();
      expect(find.text('Live aircraft'), findsOneWidget);
      failed = true;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
        hasLength(1),
      );
      expect(find.text('Live aircraft'), findsNothing);
      expect(find.text('Last known aircraft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('late geometry cannot replace another selected intent version', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    var calls = 0;
    final api = AeroArcApiClient(
      httpClient: MockClient((request) async {
        if (!request.url.path.endsWith('/map')) {
          return jsonResponse(state('fresh'));
        }
        calls++;
        return calls == 1 ? old.future : jsonResponse(mapView(2));
      }),
    );
    await tester.pumpWidget(page(api));
    await tester.pump();
    await tester.pumpWidget(page(api, version: 2));
    await tester.pumpAndSettle();
    old.complete(jsonResponse(mapView(1)));
    await tester.pumpAndSettle();
    expect(find.text('Intent boundary · v2'), findsOneWidget);
    expect(
      tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
      hasLength(1),
    );
    expect(find.textContaining('geometry unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
