import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aero_arc_web/models/aero_arc_models.dart';
import 'package:aero_arc_web/pages/aircraft_map_screen.dart';
import 'package:aero_arc_web/pages/intent_workflow_page.dart';

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

  testWidgets('AircraftMapScreen renders independently aged live groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async => sampleLiveState(),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Aircraft State'), findsOneWidget);
    expect(find.text('relay-central-1'), findsOneWidget);
    expect(find.text('Position sample'), findsOneWidget);
    expect(find.text('Battery sample'), findsOneWidget);
    expect(find.textContaining('76%'), findsOneWidget);
    expect(find.textContaining('Drop 0.4%'), findsOneWidget);
    expect(find.textContaining('Drop 40%'), findsNothing);
    expect(find.textContaining('Stale'), findsOneWidget);
    expect(
      mapCenterFor(sampleMapView(), liveState: sampleLiveState()).latitude,
      29.7604,
    );
    expect(find.text('Live Tracking'), findsOneWidget);
    expect(find.textContaining('10s projected track'), findsOneWidget);
  });

  testWidgets('live tracker polls and retains a recent breadcrumb', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async {
            calls += 1;
            return sampleLiveState(
              latitudeDeg: 29.7604 + calls / 10000,
              longitudeDeg: -95.3698 + calls / 10000,
              recordedAt: DateTime(2099, 8, 11, 12, 0, calls),
            );
          },
          liveRefreshInterval: const Duration(seconds: 1),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.textContaining('1 recent track points'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(calls, 2);
    expect(find.textContaining('2 recent track points'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed refresh retains last known tracker position', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async {
            calls += 1;
            if (calls > 1) throw Exception('registry unavailable');
            return sampleLiveState();
          },
          liveRefreshInterval: const Duration(seconds: 1),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.text('Update Delayed'), findsOneWidget);
    expect(find.textContaining('Last known live state'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'live conformance refreshes independently and retains the last good state',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: AircraftMapScreen(
            aircraftId: 'aircraft-1',
            load: () async => sampleMapView(),
            loadConformance: () async {
              calls += 1;
              if (calls == 1) return sampleConformanceDashboard();
              if (calls == 2) {
                return sampleConformanceDashboard(
                  condition: 'non_conforming',
                  phase: 'open',
                  worstDeviationM: 62.4,
                );
              }
              throw Exception('conformance unavailable');
            },
            conformanceRefreshInterval: const Duration(seconds: 1),
            renderTiles: false,
          ),
        ),
      );
      await tester.pump();

      expect(calls, 1);
      expect(find.text('Conforming'), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(calls, 2);
      expect(find.text('Non Conforming'), findsWidgets);
      expect(find.text('Lateral Deviation'), findsOneWidget);
      expect(find.text('Open · 62.4 m worst deviation'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(calls, 3);
      expect(find.text('Update Delayed'), findsOneWidget);
      expect(find.text('Non Conforming'), findsOneWidget);
      expect(find.text('Open · 62.4 m worst deviation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final connectionStatus in ['stale', 'offline', 'unmapped']) {
    testWidgets(
      'fresh position renders navigation marker with $connectionStatus connection',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: AircraftMapScreen(
              aircraftId: 'aircraft-1',
              load: () async => sampleMapView(),
              loadState: () async =>
                  sampleLiveState(connectionStatus: connectionStatus),
              renderTiles: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.navigation), findsOneWidget);
        expect(find.byIcon(Icons.question_mark_rounded), findsNothing);
      },
    );
  }

  testWidgets('stale position renders uncertain marker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async => sampleLiveState(positionStatus: 'stale'),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.navigation), findsNothing);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
  });

  testWidgets('stale HUD cannot project a fresh position', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async =>
              sampleLiveState(includePositionMotion: false, hudStatus: 'stale'),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no motion projection'), findsOneWidget);
    expect(find.textContaining('10s projected track'), findsNothing);
  });

  testWidgets('superseded conformance cannot replace the active version', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadConformance: () async => sampleConformanceDashboard(
            intentVersion: 2,
            condition: 'non_conforming',
            phase: 'open',
          ),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conforming'), findsWidgets);
    expect(find.text('Non Conforming'), findsNothing);
  });

  testWidgets('missing live position keeps historical marker uncertain', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async => sampleLiveState(includePosition: false),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.navigation), findsNothing);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);
  });

  testWidgets('live-state failure preserves map and operation content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () async => throw Exception('registry unavailable'),
          renderTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eagle 1'), findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(find.text('Connected'), findsNothing);
    expect(
      find.textContaining('Map history and operation data remain available'),
      findsOneWidget,
    );
  });

  testWidgets('pending live state does not block map content', (tester) async {
    final pendingState = Completer<AircraftLiveState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          loadState: () => pendingState.future,
          renderTiles: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Eagle 1'), findsOneWidget);
    expect(find.text('Operation'), findsOneWidget);
    expect(find.text('Conformance'), findsOneWidget);
    expect(
      find.text(
        'Live state is loading. Map history and operation data remain available.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    pendingState.complete(sampleLiveState());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AircraftMapScreen opens create route with no active intent', (
    tester,
  ) async {
    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(includeActiveIntent: false),
          renderTiles: false,
        ),
        onGenerateRoute: (settings) {
          routeArguments = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('route:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active operational intent.'), findsOneWidget);
    final createIntent = find.byTooltip('Create intent');
    await tester.ensureVisible(createIntent);
    await tester.tap(createIntent);
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/intent/new'), findsOneWidget);
    final args = routeArguments as IntentWorkflowRouteArguments;
    expect(args.initialVolumeCenter?.latitude, 35.2);
    expect(args.initialVolumeCenter?.longitude, -97.2);
  });

  testWidgets('AircraftMapScreen opens assigned intent workflow', (
    tester,
  ) async {
    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () async => sampleMapView(),
          renderTiles: false,
        ),
        onGenerateRoute: (settings) {
          routeArguments = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text('route:${settings.name}'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final openIntent = find.text('Open intent');
    await tester.ensureVisible(openIntent);
    await tester.tap(openIntent);
    await tester.pumpAndSettle();

    expect(find.text('route:/aircraft/aircraft-1/intent/new'), findsOneWidget);
    final args = routeArguments as IntentWorkflowRouteArguments;
    expect(args.initialIntent?.id, 'intent-1');
    expect(args.initialVolumes, hasLength(1));
  });

  testWidgets('AircraftMapScreen handles loading and error state', (
    tester,
  ) async {
    final pendingLoad = Completer<AircraftMapView>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AircraftMapScreen(
          aircraftId: 'aircraft-1',
          load: () => pendingLoad.future,
          renderTiles: false,
        ),
      ),
    );

    expect(find.text('Loading'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingLoad.completeError('offline');
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

  test('projected track follows current velocity for ten seconds', () {
    final position = sampleLiveState().telemetry.position!;
    final track = projectedPositionTrack(position);

    expect(track, hasLength(2));
    expect(track.first.latitude, position.latitudeDeg);
    expect(track.last.latitude, greaterThan(track.first.latitude));
    expect(track.last.longitude, greaterThan(track.first.longitude));
  });

  test('commanded mission path preserves waypoint sequence', () {
    final path = missionPath(sampleMapView().commandedMission);

    expect(path, hasLength(2));
    expect(path.first, const LatLng(35.15, -97.15));
    expect(path.last, const LatLng(35.25, -97.25));
  });

  test(
    'long mission plans declutter waypoint markers but retain endpoints',
    () {
      final indexes = missionMarkerIndexes(200);

      expect(indexes.length, lessThanOrEqualTo(31));
      expect(indexes.first, 0);
      expect(indexes.last, 199);
    },
  );
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
    commandedMission: Mission(
      id: 'mission-1',
      version: 1,
      flightId: 'flight-1',
      aircraftId: 'aircraft-1',
      intentId: 'intent-1',
      intentVersion: 1,
      sourceFormat: 'qgc_wpl_110',
      sourceSha256: List.filled(64, 'a').join(),
      missionDigest: List.filled(64, 'b').join(),
      validationFindings: const [],
      items: const [
        MissionItem(
          sequence: 0,
          current: true,
          frame: 0,
          command: 22,
          param1: 0,
          param2: 0,
          param3: 0,
          param4: 0,
          latitudeE7: 351500000,
          longitudeE7: -971500000,
          altitudeM: 100,
          autoContinue: true,
        ),
        MissionItem(
          sequence: 1,
          current: false,
          frame: 0,
          command: 16,
          param1: 0,
          param2: 0,
          param3: 0,
          param4: 0,
          latitudeE7: 352500000,
          longitudeE7: -972500000,
          altitudeM: 110,
          autoContinue: true,
        ),
      ],
    ),
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

ConformanceDashboard sampleConformanceDashboard({
  int intentVersion = 1,
  String condition = 'conforming',
  String phase = 'clear',
  double? worstDeviationM,
}) {
  return ConformanceDashboard(
    metrics: const [],
    summaries: [
      ConformanceSummary(
        id: 'live-summary-1',
        intentId: 'intent-1',
        intentVersion: intentVersion,
        aircraftId: 'aircraft-1',
        status: condition,
        alertCount: phase == 'clear' ? 0 : 1,
        reportabilityStatus: 'no',
        assignmentId: 'assignment-1',
        condition: condition,
        monitoringStatus: 'current',
        recordingStatus: 'confirmed',
        observedAt: DateTime(2099, 8, 11, 12),
        violations: [
          ConformanceViolation(
            type: 'lateral_deviation',
            phase: phase,
            worstDeviationM: worstDeviationM,
          ),
        ],
      ),
    ],
    events: const [],
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

AircraftLiveState sampleLiveState({
  String connectionStatus = 'connected',
  String positionStatus = 'fresh',
  bool includePosition = true,
  bool includePositionMotion = true,
  String? hudStatus,
  double latitudeDeg = 29.7604,
  double longitudeDeg = -95.3698,
  DateTime? recordedAt,
}) {
  final sampleTime = recordedAt ?? DateTime(2099, 8, 11, 12);
  return AircraftLiveState(
    aircraftId: 'aircraft-1',
    agentId: 'agent-1',
    connection: AircraftConnectionState(
      aircraftId: 'aircraft-1',
      agentId: 'agent-1',
      relayId: 'relay-central-1',
      connected: connectionStatus == 'connected',
      status: connectionStatus,
      lastHeartbeatAt: DateTime(2099, 8, 11, 12),
    ),
    telemetry: AircraftTelemetryState(
      status: 'fresh',
      lastObservedAt: sampleTime,
      position: includePosition
          ? PositionTelemetry(
              status: positionStatus,
              recordedAt: sampleTime,
              latitudeDeg: latitudeDeg,
              longitudeDeg: longitudeDeg,
              relativeAltitudeM: 21.2,
              velocityNorthMps: includePositionMotion ? 8 : null,
              velocityEastMps: includePositionMotion ? 6 : null,
              groundspeedMps: includePositionMotion ? 10 : null,
              headingDeg: includePositionMotion ? 36.9 : null,
            )
          : null,
      battery: BatteryTelemetry(
        status: 'stale',
        recordedAt: DateTime(2099, 8, 11, 11, 59),
        batteryId: 0,
        remainingPct: 76,
        voltageV: 22.4,
      ),
      vehicle: VehicleTelemetry(
        status: 'fresh',
        recordedAt: DateTime(2099, 8, 11, 12),
        baseMode: 'mav_mode_flag_safety_armed',
        systemStatus: 'mav_state_active',
      ),
      system: SystemTelemetry(
        status: 'fresh',
        recordedAt: DateTime(2099, 8, 11, 12),
        mainloopLoadPct: 43.2,
        communicationDropRatePct: 0.4,
      ),
      hud: hudStatus == null
          ? null
          : HudTelemetry(
              status: hudStatus,
              recordedAt: DateTime(2099, 8, 11, 11, 59),
              groundspeedMps: 12,
              headingDeg: 90,
            ),
    ),
  );
}
