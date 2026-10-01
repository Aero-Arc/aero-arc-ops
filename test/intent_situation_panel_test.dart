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

OperationalIntent intent(int version, {String status = 'active'}) =>
    OperationalIntent.fromJson({
      'id': 'intent-1',
      'aircraft_id': 'aircraft-1',
      'version': version,
      'status': status,
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
  testWidgets('stalled geometry can be retried after timeout', (tester) async {
    final stalled = Completer<http.Response>();
    var reads = 0;
    final api = AeroArcApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/volumes')) {
          reads++;
          return reads == 1
              ? stalled.future
              : jsonResponse({'volumes': mapView(1)['operational_volumes']});
        }
        return jsonResponse(state('fresh'));
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntentSituationPanel(
              api: api,
              intent: intent(1, status: 'accepted'),
              aircraftId: 'aircraft-1',
              renderTiles: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(find.textContaining('Saved geometry unavailable:'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh operation map'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.textContaining('Saved geometry unavailable:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'stalled live state marks unavailable and later polling recovers',
    (tester) async {
      final stalled = Completer<http.Response>();
      final recovered = Completer<http.Response>();
      var reads = 0;
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/state')) {
            reads++;
            return reads == 1 ? stalled.future : recovered.future;
          }
          return jsonResponse(mapView(1));
        }),
      );
      await tester.pumpWidget(page(api));
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(find.textContaining('Live state unavailable'), findsOneWidget);
      recovered.complete(jsonResponse(state('fresh')));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(reads, greaterThan(1));
      expect(find.textContaining('Live state unavailable'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'same-intent added volume replaces empty geometry and stale read',
    (tester) async {
      final staleRead = Completer<http.Response>();
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/volumes')) {
            return staleRead.future;
          }
          return jsonResponse(state('missing'));
        }),
      );
      Widget view(List<OperationalVolume> volumes) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntentSituationPanel(
              api: api,
              intent: intent(1, status: 'accepted'),
              aircraftId: 'aircraft-1',
              renderTiles: false,
              initialVolumes: volumes,
            ),
          ),
        ),
      );
      await tester.pumpWidget(view([]));
      await tester.pump();
      final volume = OperationalVolume.fromJson(
        (mapView(1)['operational_volumes'] as List).single
            as Map<String, dynamic>,
      );
      await tester.pumpWidget(view([volume]));
      await tester.pump();
      staleRead.complete(jsonResponse({'volumes': []}));
      await tester.pumpAndSettle();
      expect(find.textContaining('No saved geometry'), findsNothing);
      expect(
        tester
            .widgetList<PolygonLayer>(find.byType(PolygonLayer))
            .any((p) => p.polygons.isNotEmpty),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in ['accepted', 'complete', 'canceled']) {
    testWidgets('$status geometry uses the exact saved intent version', (
      tester,
    ) async {
      var geometryRead = false;
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/volumes')) {
            expect(request.url.queryParameters['version'], '2');
            geometryRead = true;
            return jsonResponse({'volumes': mapView(2)['operational_volumes']});
          }
          expect(request.url.path.endsWith('/map'), isFalse);
          return jsonResponse(state('fresh'));
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntentSituationPanel(
              api: api,
              intent: intent(2, status: status),
              aircraftId: 'aircraft-1',
              renderTiles: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(geometryRead, isTrue);
      expect(find.textContaining('Saved geometry unavailable'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final connection in [
    'connected',
    'stale',
    'offline',
    'unmapped',
    'unavailable',
  ]) {
    testWidgets('shows $connection registry independently of fresh position', (
      tester,
    ) async {
      final api = AeroArcApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/map')) {
            return jsonResponse(mapView(1));
          }
          return jsonResponse({
            ...state('fresh'),
            'connection': {'connection_status': connection},
          });
        }),
      );
      await tester.pumpWidget(page(api));
      await tester.pumpAndSettle();
      expect(find.text('REGISTRY CONNECTION'), findsOneWidget);
      expect(find.text(connection), findsOneWidget);
      expect(find.text('POSITION · fresh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
