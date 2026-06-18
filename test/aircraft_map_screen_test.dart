import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/aircraft_map_screen.dart';

void main() {
  testWidgets('AircraftMapScreen renders aircraft header data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eagle 1'), findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
    expect(find.text('Conformance'), findsOneWidget);
  });

  testWidgets('AircraftMapScreen renders no active intent empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(includeActiveIntent: false),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active operational intent.'), findsOneWidget);
  });

  testWidgets('AircraftMapScreen handles loading and error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () => Future<AircraftMapView>.error('offline'),
          renderTiles: false,
        ),
      ),
    );

    expect(find.text('Loading'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
  });

  test('map helpers handle replay samples and conformance event positions', () {
    final view = sampleMapView();
    expect(replayPath(view.replaySamples), hasLength(2));
    expect(volumePolygons(view.operationalVolumes), hasLength(1));
    expect(mapCenterFor(view).latitude, 35.2);
    expect(
      polygonExteriorRings(view.operationalVolumes.single.geoJson!),
      hasLength(1),
    );
  });
}

AircraftMapView sampleMapView({bool includeActiveIntent = true}) {
  final intent = includeActiveIntent ? sampleIntent() : null;
  return AircraftMapView(
    aircraft: const Aircraft(
      id: 'aircraft-1',
      tailNumber: 'N100AA',
      name: 'Eagle 1',
      model: 'ArcRunner',
      manufacturer: 'Aero Arc',
      status: 'active',
      acceptanceStatus: 'accepted',
      remoteIdStatus: 'broadcasting',
    ),
    liveStateAvailable: true,
    liveState: const LiveAircraftState(
      aircraftId: 'aircraft-1',
      agentId: 'agent-1',
      relayId: 'relay-1',
      connected: true,
    ),
    latestTelemetry: sampleTelemetry('sample-2', 35.2, -97.2),
    replaySamples: [
      sampleTelemetry('sample-1', 35.1, -97.1),
      sampleTelemetry('sample-2', 35.2, -97.2),
    ],
    activeIntent: intent,
    operationalVolumes: [
      const OperationalVolume(
        id: 'volume-1',
        intentId: 'intent-1',
        intentVersion: 1,
        sequence: 1,
        geoJson:
            '{"type":"Polygon","coordinates":[[[-98,35],[-97,35],[-97,36],[-98,36],[-98,35]]]}',
        minAltitudeM: 10,
        maxAltitudeM: 120,
        altitudeRef: 'agl',
      ),
    ],
    conformanceSummary: const ConformanceSummary(
      id: 'summary-1',
      intentId: 'intent-1',
      intentVersion: 1,
      aircraftId: 'aircraft-1',
      status: 'conforming',
      alertCount: 1,
      reportabilityStatus: 'review',
    ),
    conformanceEvents: const [
      ConformanceEvent(
        id: 'event-1',
        intentId: 'intent-1',
        intentVersion: 1,
        aircraftId: 'aircraft-1',
        severity: 'warning',
        eventCode: 'intent_exit',
        message: 'outside volume',
        latitude: 35.3,
        longitude: -97.3,
      ),
    ],
  );
}

OperationalIntent sampleIntent() {
  return const OperationalIntent(
    id: 'intent-1',
    aircraftId: 'aircraft-1',
    version: 1,
    name: 'Pipeline patrol',
    summary: 'Inspect corridor',
    authorizationPath: 'permit',
    populationCategory: 'cat_2',
    status: 'active',
    conformanceRequired: true,
  );
}

TelemetrySample sampleTelemetry(String id, double lat, double lon) {
  return TelemetrySample(
    id: id,
    aircraftId: 'aircraft-1',
    recordedAt: DateTime.parse('2026-06-14T12:00:00Z'),
    latitude: lat,
    longitude: lon,
    altitudeM: 90,
    velocityMps: 12,
    headingDeg: 180,
  );
}
