import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';
import 'intent_workflow_page.dart';

class AircraftMapScreen extends StatefulWidget {
  const AircraftMapScreen({
    super.key,
    required this.aircraftId,
    this.load,
    this.loadState,
    this.loadConformance,
    this.limit = 1000,
    this.renderTiles = true,
    this.liveRefreshInterval = const Duration(seconds: 1),
    this.conformanceRefreshInterval = const Duration(seconds: 1),
    this.liveTrailLimit = 60,
  }) : assert(liveRefreshInterval > Duration.zero),
       assert(conformanceRefreshInterval > Duration.zero),
       assert(liveTrailLimit > 0);

  final String aircraftId;
  final int limit;
  final Future<AircraftMapView> Function()? load;
  final Future<AircraftLiveState> Function()? loadState;
  final Future<ConformanceDashboard> Function()? loadConformance;
  final bool renderTiles;
  final Duration liveRefreshInterval;
  final Duration conformanceRefreshInterval;
  final int liveTrailLimit;

  @override
  State<AircraftMapScreen> createState() => _AircraftMapScreenState();
}

class _AircraftMapScreenState extends State<AircraftMapScreen> {
  late Future<AircraftMapView> _future;
  AircraftLiveState? _liveState;
  Object? _liveStateError;
  bool _liveStateLoading = false;
  List<ConformanceSummary> _liveConformance = const [];
  Object? _conformanceError;
  bool _conformanceLoading = false;
  int _loadGeneration = 0;
  Timer? _liveRefreshTimer;
  Timer? _conformanceRefreshTimer;
  final List<LatLng> _liveTrail = [];
  DateTime? _lastTrackRecordedAt;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AircraftMapView> _load() {
    final generation = ++_loadGeneration;
    final custom = widget.load;
    final client = AeroArcApiClient();
    final mapFuture = custom != null
        ? Future<AircraftMapView>.sync(custom)
        : Future<AircraftMapView>.sync(
            () => client.getAircraftMapView(
              widget.aircraftId,
              limit: widget.limit,
            ),
          );
    final stateLoader =
        widget.loadState ??
        (custom == null
            ? () => client.getAircraftState(widget.aircraftId)
            : null);
    final conformanceLoader =
        widget.loadConformance ?? (custom == null ? client.conformance : null);
    _liveStateLoading = stateLoader != null;
    if (stateLoader != null) {
      unawaited(_loadLiveState(stateLoader, generation));
    }
    _conformanceLoading = conformanceLoader != null;
    if (conformanceLoader != null) {
      unawaited(_loadConformance(conformanceLoader, generation));
    }
    return mapFuture;
  }

  Future<void> _loadLiveState(
    Future<AircraftLiveState> Function() loader,
    int generation,
  ) async {
    final result = await _captureLiveState(
      Future<AircraftLiveState>.sync(loader),
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      if (result.state != null) {
        _liveState = result.state;
        _recordLiveTrack(result.state!);
      }
      _liveStateError = result.error;
      _liveStateLoading = false;
    });
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer(
      widget.liveRefreshInterval,
      () => _loadLiveState(loader, generation),
    );
  }

  Future<void> _loadConformance(
    Future<ConformanceDashboard> Function() loader,
    int generation,
  ) async {
    final result = await _captureConformance(
      Future<ConformanceDashboard>.sync(loader),
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      if (result.dashboard != null) {
        _liveConformance = result.dashboard!.summaries;
      }
      _conformanceError = result.error;
      _conformanceLoading = false;
    });
    _conformanceRefreshTimer?.cancel();
    _conformanceRefreshTimer = Timer(
      widget.conformanceRefreshInterval,
      () => _loadConformance(loader, generation),
    );
  }

  void _recordLiveTrack(AircraftLiveState state) {
    final position = state.telemetry.position;
    if (position == null || position.status != 'fresh') return;
    if (_lastTrackRecordedAt == position.recordedAt) return;
    final point = LatLng(position.latitudeDeg, position.longitudeDeg);
    if (_liveTrail.isEmpty || _liveTrail.last != point) {
      _liveTrail.add(point);
      final overflow = _liveTrail.length - widget.liveTrailLimit;
      if (overflow > 0) _liveTrail.removeRange(0, overflow);
    }
    _lastTrackRecordedAt = position.recordedAt;
  }

  void _refresh() {
    _liveRefreshTimer?.cancel();
    _conformanceRefreshTimer?.cancel();
    setState(() {
      _liveState = null;
      _liveStateError = null;
      _conformanceError = null;
      _liveTrail.clear();
      _lastTrackRecordedAt = null;
      _future = _load();
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _conformanceRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: aeroPageGradient),
      child: FutureBuilder<AircraftMapView>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22, 20, 22, 24),
                  child: LoadingPanel(),
                ),
                _MapLoadingIndicator(),
              ],
            );
          }
          if (snapshot.hasError) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              child: ErrorPanel(
                error: snapshot.error.toString(),
                onRetry: _refresh,
              ),
            );
          }
          final view = snapshot.data;
          if (view == null) {
            return const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 24),
              child: EmptyPanel(message: 'No aircraft map data is available.'),
            );
          }

          final liveConformance = _selectConformanceSummary(
            _liveConformance,
            aircraftId: widget.aircraftId,
            intentId: view.activeIntent?.id,
            intentVersion: view.activeIntent?.version,
          );
          final embeddedConformance = _boundConformanceSummary(
            view.conformanceSummary,
            aircraftId: widget.aircraftId,
            intentId: view.activeIntent?.id,
            intentVersion: view.activeIntent?.version,
          );

          return _AircraftMapContent(
            view: view,
            liveState: _liveState,
            liveStateError: _liveStateError,
            liveStateLoading: _liveStateLoading,
            conformanceSummary: liveConformance ?? embeddedConformance,
            conformanceError: _conformanceError,
            conformanceLoading: _conformanceLoading,
            liveTrail: List.unmodifiable(_liveTrail),
            onRefresh: _refresh,
            renderTiles: widget.renderTiles,
          );
        },
      ),
    );
  }
}

ConformanceSummary? _selectConformanceSummary(
  List<ConformanceSummary> summaries, {
  required String aircraftId,
  String? intentId,
  int? intentVersion,
}) {
  if (intentId == null || intentVersion == null) return null;
  final matchingAircraft = summaries
      .where((summary) => summary.aircraftId == aircraftId)
      .toList();
  if (matchingAircraft.isEmpty) return null;
  final candidates = matchingAircraft
      .where(
        (summary) =>
            summary.intentId == intentId &&
            summary.intentVersion == intentVersion,
      )
      .toList();
  if (candidates.isEmpty) return null;
  candidates.sort((left, right) {
    if (left.isLiveProjection != right.isLiveProjection) {
      return left.isLiveProjection ? -1 : 1;
    }
    final leftAt = left.observedAt ?? left.updatedAt;
    final rightAt = right.observedAt ?? right.updatedAt;
    if (leftAt == null) return rightAt == null ? 0 : 1;
    if (rightAt == null) return -1;
    return rightAt.compareTo(leftAt);
  });
  return candidates.first;
}

ConformanceSummary? _boundConformanceSummary(
  ConformanceSummary? summary, {
  required String aircraftId,
  String? intentId,
  int? intentVersion,
}) {
  if (summary == null || intentId == null || intentVersion == null) return null;
  return summary.aircraftId == aircraftId &&
          summary.intentId == intentId &&
          summary.intentVersion == intentVersion
      ? summary
      : null;
}

Future<_LiveStateResult> _captureLiveState(
  Future<AircraftLiveState> future,
) async {
  try {
    return _LiveStateResult(state: await future);
  } catch (error) {
    return _LiveStateResult(error: error);
  }
}

Future<_ConformanceResult> _captureConformance(
  Future<ConformanceDashboard> future,
) async {
  try {
    return _ConformanceResult(dashboard: await future);
  } catch (error) {
    return _ConformanceResult(error: error);
  }
}

class _LiveStateResult {
  const _LiveStateResult({this.state, this.error});

  final AircraftLiveState? state;
  final Object? error;
}

class _ConformanceResult {
  const _ConformanceResult({this.dashboard, this.error});

  final ConformanceDashboard? dashboard;
  final Object? error;
}

class _MapLoadingIndicator extends StatelessWidget {
  const _MapLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 18,
      bottom: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF07132E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF12254F)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _AircraftMapContent extends StatelessWidget {
  const _AircraftMapContent({
    required this.view,
    required this.liveState,
    required this.liveStateError,
    required this.liveStateLoading,
    required this.conformanceSummary,
    required this.conformanceError,
    required this.conformanceLoading,
    required this.liveTrail,
    required this.onRefresh,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final Object? liveStateError;
  final bool liveStateLoading;
  final ConformanceSummary? conformanceSummary;
  final Object? conformanceError;
  final bool conformanceLoading;
  final List<LatLng> liveTrail;
  final VoidCallback onRefresh;
  final bool renderTiles;

  @override
  Widget build(BuildContext context) {
    final center = mapCenterFor(view, liveState: liveState);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MapHeader(
            view: view,
            liveState: liveState,
            liveStateLoading: liveStateLoading,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1180) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _MapPanel(
                        view: view,
                        liveState: liveState,
                        liveStateError: liveStateError,
                        liveTrail: liveTrail,
                        center: center,
                        renderTiles: renderTiles,
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 390,
                      child: _DetailPanel(
                        view: view,
                        liveState: liveState,
                        liveStateError: liveStateError,
                        liveStateLoading: liveStateLoading,
                        conformanceSummary: conformanceSummary,
                        conformanceError: conformanceError,
                        conformanceLoading: conformanceLoading,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _MapPanel(
                    view: view,
                    liveState: liveState,
                    liveStateError: liveStateError,
                    liveTrail: liveTrail,
                    center: center,
                    renderTiles: renderTiles,
                  ),
                  const SizedBox(height: 18),
                  _DetailPanel(
                    view: view,
                    liveState: liveState,
                    liveStateError: liveStateError,
                    liveStateLoading: liveStateLoading,
                    conformanceSummary: conformanceSummary,
                    conformanceError: conformanceError,
                    conformanceLoading: conformanceLoading,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.view,
    required this.liveState,
    required this.liveStateLoading,
    required this.onRefresh,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final bool liveStateLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final aircraft = view.aircraft;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aircraft.displayName,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 42),
              ),
              const SizedBox(height: 8),
              Text(
                '${aircraft.tailNumber.isEmpty ? aircraft.id : aircraft.tailNumber} - ${aircraft.model.isEmpty ? 'Aircraft map' : aircraft.model}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusBadge(label: aircraft.status),
                  StatusBadge(label: aircraft.remoteIdStatus),
                  StatusBadge(
                    label:
                        liveState?.connection.status ??
                        (liveStateLoading ? 'loading' : 'unavailable'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({
    required this.view,
    required this.liveState,
    required this.liveStateError,
    required this.liveTrail,
    required this.center,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final Object? liveStateError;
  final List<LatLng> liveTrail;
  final LatLng center;
  final bool renderTiles;

  @override
  Widget build(BuildContext context) {
    final path = replayPath(view.replaySamples);
    final mission = view.validatedMission;
    final commandedRoute = missionPath(mission);
    final polygons = volumePolygons(view.operationalVolumes);
    final livePosition = liveState?.telemetry.position;
    final livePositionAvailable = livePosition?.status == 'fresh';
    final hud = liveState?.telemetry.hud;
    final freshHud = hud?.status == 'fresh' ? hud : null;
    final heading = livePosition?.headingDeg ?? freshHud?.headingDeg;
    final projectedTrack = livePositionAvailable
        ? projectedPositionTrack(
            livePosition!,
            fallbackGroundspeedMps: freshHud?.groundspeedMps,
            fallbackHeadingDeg: freshHud?.headingDeg,
          )
        : const <LatLng>[];
    final speed = livePosition == null
        ? null
        : positionGroundspeed(
            livePosition,
            fallbackGroundspeedMps: freshHud?.groundspeedMps,
          );
    final markers = <Marker>[
      if (path.isNotEmpty)
        Marker(
          point: path.first,
          width: 38,
          height: 38,
          child: const _MapMarker(
            color: Color(0xFF5E6FFF),
            icon: Icons.home_rounded,
          ),
        ),
      if (livePosition != null || view.latestTelemetry != null)
        Marker(
          point: livePosition == null
              ? telemetryPoint(view.latestTelemetry!)
              : LatLng(livePosition.latitudeDeg, livePosition.longitudeDeg),
          width: 42,
          height: 42,
          child: _MapMarker(
            color: livePositionAvailable
                ? const Color(0xFF00CFA0)
                : const Color(0xFFE4A100),
            icon: livePositionAvailable
                ? Icons.navigation
                : Icons.question_mark_rounded,
            rotationRadians: livePositionAvailable && heading != null
                ? heading * math.pi / 180
                : 0,
          ),
        ),
      for (final index in missionMarkerIndexes(commandedRoute.length))
        Marker(
          point: commandedRoute[index],
          width: 34,
          height: 34,
          child: _MissionWaypointMarker(item: mission!.items[index]),
        ),
      for (final event in view.conformanceEvents)
        if (event.latitude != null && event.longitude != null)
          Marker(
            point: LatLng(event.latitude!, event.longitude!),
            width: 38,
            height: 38,
            child: const _MapMarker(
              color: Color(0xFFE14A5B),
              icon: Icons.warning_amber_rounded,
            ),
          ),
    ];

    return Panel(
      title: 'Aircraft Map',
      trailing: StatusBadge(
        label: liveStateError != null
            ? 'update_delayed'
            : livePositionAvailable
            ? 'live_tracking'
            : 'tracking_unavailable',
      ),
      child: SizedBox(
        height: 560,
        child: Stack(
          children: [
            _FollowingMap(
              center: center,
              children: [
                if (renderTiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'aero_arc_web',
                  ),
                if (polygons.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      for (final polygon in polygons)
                        Polygon(
                          points: polygon,
                          color: const Color(
                            0xFF5A6BFF,
                          ).withValues(alpha: 0.18),
                          borderColor: const Color(0xFF6B75FF),
                          borderStrokeWidth: 2,
                        ),
                    ],
                  ),
                if (path.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: path,
                        strokeWidth: 3,
                        color: const Color(0xFF5E6FFF),
                      ),
                    ],
                  ),
                if (commandedRoute.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: commandedRoute,
                        strokeWidth: 4,
                        color: const Color(0xFF43C6FF),
                      ),
                    ],
                  ),
                if (liveTrail.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: liveTrail,
                        strokeWidth: 5,
                        color: const Color(0xFF00CFA0),
                      ),
                    ],
                  ),
                if (projectedTrack.length == 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: projectedTrack,
                        strokeWidth: 3,
                        color: const Color(0xFFE4A100),
                      ),
                    ],
                  ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _TrackerReadout(
                position: livePosition,
                speedMps: speed,
                headingDeg: heading,
                sampleCount: liveTrail.length,
                projecting: projectedTrack.length == 2,
                updateDelayed: liveStateError != null,
              ),
            ),
            const Positioned(bottom: 12, left: 12, child: _MapLegend()),
          ],
        ),
      ),
    );
  }
}

class _MissionWaypointMarker extends StatelessWidget {
  const _MissionWaypointMarker({required this.item});

  final MissionItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Mission item ${item.sequence}, ${missionCommandLabel(item.command)}, ${item.altitudeM.toStringAsFixed(0)} meters MSL',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF07132E),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF43C6FF), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            '${item.sequence}',
            style: const TextStyle(
              color: Color(0xFFDFF6FF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.color,
    required this.icon,
    this.rotationRadians = 0,
  });

  final Color color;
  final IconData icon;
  final double rotationRadians;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
      ),
      child: Transform.rotate(
        angle: rotationRadians,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _FollowingMap extends StatefulWidget {
  const _FollowingMap({required this.center, required this.children});

  final LatLng center;
  final List<Widget> children;

  @override
  State<_FollowingMap> createState() => _FollowingMapState();
}

class _FollowingMapState extends State<_FollowingMap> {
  final MapController _controller = MapController();
  bool _following = true;

  @override
  void didUpdateWidget(covariant _FollowingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_following || oldWidget.center == widget.center) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveToLivePosition();
    });
  }

  void _moveToLivePosition() {
    _controller.move(widget.center, _controller.camera.zoom);
  }

  void _setFollowing(bool selected) {
    setState(() => _following = selected);
    if (selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveToLivePosition();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: widget.center, initialZoom: 15),
          children: widget.children,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: IconButton.filledTonal(
              onPressed: () => _setFollowing(!_following),
              icon: Icon(_following ? Icons.gps_fixed : Icons.gps_not_fixed),
              tooltip: _following
                  ? 'Pause live map follow'
                  : 'Follow live position',
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackerReadout extends StatelessWidget {
  const _TrackerReadout({
    required this.position,
    required this.speedMps,
    required this.headingDeg,
    required this.sampleCount,
    required this.projecting,
    required this.updateDelayed,
  });

  final PositionTelemetry? position;
  final double? speedMps;
  final double? headingDeg;
  final int sampleCount;
  final bool projecting;
  final bool updateDelayed;

  @override
  Widget build(BuildContext context) {
    final fresh = position?.status == 'fresh';
    final moving = fresh && (speedMps ?? 0) >= 0.5;
    final motion = updateDelayed
        ? 'Last known position'
        : !fresh
        ? 'Position ${displayEnum(position?.status ?? 'unavailable')}'
        : moving
        ? 'Moving ${speedMps!.toStringAsFixed(1)} m/s'
        : 'Holding position';
    final direction = headingDeg == null
        ? ''
        : ' · ${headingDeg!.round().toString().padLeft(3, '0')}°';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xED07132E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF183263)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              motion + direction,
              style: const TextStyle(
                color: Color(0xFFE7EEFF),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              updateDelayed
                  ? '$sampleCount recent track points · live update delayed'
                  : projecting
                  ? '10s projected track · $sampleCount recent track points'
                  : '$sampleCount recent track points · no motion projection',
              style: const TextStyle(color: Color(0xFF93A3C7), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE607132E),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFF183263)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _MapLegendItem(color: Color(0xFF5E6FFF), label: 'History'),
            _MapLegendItem(
              color: Color(0xFF6B75FF),
              label: 'Authorized volume',
            ),
            _MapLegendItem(color: Color(0xFF43C6FF), label: 'Validated plan'),
            _MapLegendItem(color: Color(0xFF00CFA0), label: 'Live trail'),
            _MapLegendItem(color: Color(0xFFE4A100), label: '10s projection'),
          ],
        ),
      ),
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  const _MapLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB8C5E3), fontSize: 11),
        ),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.view,
    required this.liveState,
    required this.liveStateError,
    required this.liveStateLoading,
    required this.conformanceSummary,
    required this.conformanceError,
    required this.conformanceLoading,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final Object? liveStateError;
  final bool liveStateLoading;
  final ConformanceSummary? conformanceSummary;
  final Object? conformanceError;
  final bool conformanceLoading;

  @override
  Widget build(BuildContext context) {
    final telemetry = view.latestTelemetry;
    final intent = view.activeIntent;
    final mission = view.validatedMission;
    final summary = conformanceSummary;
    final skippedVolumes = view.operationalVolumes
        .where((volume) => (volume.geoJson ?? '').isEmpty)
        .length;

    return Column(
      children: [
        _AircraftLiveStatePanel(
          state: liveState,
          error: liveStateError,
          loading: liveStateLoading,
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Validated Mission Plan',
          trailing: StatusBadge(
            label: view.missionBindingMismatch
                ? 'binding_mismatch'
                : mission == null
                ? 'not_available'
                : 'validated',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                DetailLine(
                  label: 'Route',
                  value: view.missionBindingMismatch
                      ? 'Mission hidden because its aircraft or exact intent-version binding is inconsistent.'
                      : mission == null
                      ? 'No mission is bound to this active intent.'
                      : '${mission.items.length} waypoint item(s)',
                ),
                if (mission != null) ...[
                  DetailLine(label: 'Flight', value: mission.flightId),
                  DetailLine(
                    label: 'Intent binding',
                    value: '${mission.intentId} v${mission.intentVersion}',
                  ),
                  DetailLine(
                    label: 'Mission version',
                    value: '${mission.version}',
                  ),
                  DetailLine(
                    label: 'Digest',
                    value: _mapShortDigest(mission.missionDigest),
                  ),
                ],
                const DetailLine(
                  label: 'Meaning',
                  value:
                      'Cyan is the API-validated plan. Violet is authorization. Green is observed flight.',
                ),
                const DetailLine(
                  label: 'Aircraft deployment',
                  value:
                      'Not reported by this API view. Validation alone does not prove the route is onboard.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Operation',
          trailing: intent == null
              ? IconButton.filledTonal(
                  tooltip: 'Create intent',
                  onPressed: () => _openCreateIntent(context, view),
                  icon: const Icon(Icons.add_task),
                )
              : TextButton.icon(
                  onPressed: () => _openAssignedIntent(context, view),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open intent'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF91A0FF),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                if (intent == null)
                  const DetailLine(
                    label: 'Intent',
                    value: 'No active operational intent.',
                  )
                else ...[
                  DetailLine(
                    label: 'Intent',
                    value: intent.name.isEmpty ? intent.id : intent.name,
                  ),
                  DetailLine(
                    label: 'Status',
                    value: displayEnum(intent.status),
                  ),
                  DetailLine(
                    label: 'Window',
                    value:
                        '${formatDate(intent.plannedStartAt)} -> ${formatDate(intent.plannedEndAt)}',
                  ),
                ],
                DetailLine(
                  label: 'Volumes',
                  value: view.operationalVolumes.isEmpty
                      ? 'No operational volumes available.'
                      : '${view.operationalVolumes.length} operational volume(s)',
                ),
                if (skippedVolumes > 0)
                  DetailLine(
                    label: 'Map warning',
                    value:
                        '$skippedVolumes volume(s) skipped because inline GeoJSON is unavailable.',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Conformance',
          trailing: StatusBadge(
            label: conformanceError != null
                ? 'update_delayed'
                : conformanceLoading
                ? 'loading'
                : summary?.condition ?? summary?.status ?? 'unavailable',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                DetailLine(
                  label: 'Status',
                  value: summary == null
                      ? 'No conformance summary.'
                      : displayEnum(summary.condition ?? summary.status),
                ),
                DetailLine(
                  label: summary?.isLiveProjection == true
                      ? 'Active findings'
                      : 'Alerts',
                  value:
                      '${summary?.isLiveProjection == true ? summary?.activeViolationCount : summary?.alertCount ?? view.conformanceEvents.length}',
                ),
                if (summary?.isLiveProjection == true) ...[
                  DetailLine(
                    label: 'Monitoring',
                    value: displayEnum(
                      summary?.monitoringStatus ?? 'unavailable',
                    ),
                  ),
                  DetailLine(
                    label: 'Recording',
                    value: displayEnum(
                      summary?.recordingStatus ?? 'unavailable',
                    ),
                  ),
                  DetailLine(
                    label: 'Observed',
                    value: formatDate(summary?.observedAt),
                  ),
                  for (final violation in summary?.activeViolations ?? const [])
                    DetailLine(
                      label: displayEnum(violation.type),
                      value: [
                        displayEnum(violation.phase),
                        if (violation.worstDeviationM != null)
                          '${violation.worstDeviationM!.toStringAsFixed(1)} m worst deviation',
                      ].join(' · '),
                    ),
                ],
                DetailLine(
                  label: 'Reportability',
                  value: summary == null
                      ? 'Not provided'
                      : displayEnum(summary.reportabilityStatus),
                ),
                DetailLine(
                  label: 'Telemetry',
                  value: telemetry == null
                      ? 'No latest telemetry.'
                      : '${formatDate(telemetry.recordedAt)}\n${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)}\nAltitude ${formatMeters(telemetry.altitudeM)}',
                ),
                DetailLine(
                  label: 'Battery',
                  value: formatPercentagePoints(telemetry?.batteryPct),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Conformance Events',
          child: RowList(
            children: [
              for (final event in view.conformanceEvents.take(8))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE14A5B),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${displayEnum(event.eventCode)} - ${event.message}\n${formatDate(event.occurredAt)}',
                        style: const TextStyle(
                          color: Color(0xFFC4D0EE),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AircraftLiveStatePanel extends StatelessWidget {
  const _AircraftLiveStatePanel({
    required this.state,
    required this.error,
    required this.loading,
  });

  final AircraftLiveState? state;
  final Object? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state == null) {
      return Panel(
        title: 'Live Aircraft State',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(label: loading ? 'loading' : 'unavailable'),
              const SizedBox(height: 10),
              Text(
                loading
                    ? 'Live state is loading. Map history and operation data remain available.'
                    : error == null
                    ? 'Live state was not requested for this view.'
                    : 'Registry or telemetry state could not be loaded. Map history and operation data remain available.',
                style: const TextStyle(color: Color(0xFF93A3C7)),
              ),
            ],
          ),
        ),
      );
    }
    final connection = state.connection;
    final telemetry = state.telemetry;
    return Panel(
      title: 'Live Aircraft State',
      trailing: StatusBadge(label: connection.status),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          children: [
            DetailLine(label: 'Agent', value: connection.agentId ?? 'Unmapped'),
            DetailLine(label: 'Relay', value: connection.relayId ?? 'Unplaced'),
            DetailLine(
              label: 'Registry heartbeat',
              value: _mapTimestamp(connection.lastHeartbeatAt),
            ),
            DetailLine(
              label: 'Telemetry',
              value:
                  '${displayEnum(telemetry.status)} · ${_mapTimestamp(telemetry.lastObservedAt)}',
            ),
            if (error != null)
              const DetailLine(
                label: 'Tracker refresh',
                value:
                    'Update delayed. Last known live state remains on the map.',
              ),
            DetailLine(
              label: 'Position sample',
              value: telemetry.position == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.position!.status)} · ${_mapTimestamp(telemetry.position!.recordedAt)}\n${telemetry.position!.latitudeDeg.toStringAsFixed(5)}, ${telemetry.position!.longitudeDeg.toStringAsFixed(5)}\nAltitude ${formatMeters(telemetry.position!.relativeAltitudeM ?? telemetry.position!.altitudeMslM)}',
            ),
            DetailLine(
              label: 'Battery sample',
              value: telemetry.battery == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.battery!.status)} · ${_mapTimestamp(telemetry.battery!.recordedAt)}\n${formatPercentagePoints(telemetry.battery!.remainingPct)} · ${_mapUnit(telemetry.battery!.voltageV, 'V')} · ${_mapUnit(telemetry.battery!.currentA, 'A')}',
            ),
            DetailLine(
              label: 'Vehicle heartbeat',
              value: telemetry.vehicle == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.vehicle!.status)} · ${_mapTimestamp(telemetry.vehicle!.recordedAt)}\n${switch (telemetry.vehicle!.armed) {
                      true => 'Armed',
                      false => 'Disarmed',
                      null => 'Arm state unknown',
                    }} · System ${telemetry.vehicle!.systemStatus ?? 'unknown'}',
            ),
            DetailLine(
              label: 'System sample',
              value: telemetry.system == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.system!.status)} · ${_mapTimestamp(telemetry.system!.recordedAt)}\nLoad ${formatPercentagePoints(telemetry.system!.mainloopLoadPct)} · Drop ${formatPercentagePoints(telemetry.system!.communicationDropRatePct)}',
            ),
            DetailLine(
              label: 'HUD sample',
              value: telemetry.hud == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.hud!.status)} · ${_mapTimestamp(telemetry.hud!.recordedAt)}\nGround ${_mapUnit(telemetry.hud!.groundspeedMps, 'm/s')} · Air ${_mapUnit(telemetry.hud!.airspeedMps, 'm/s')}',
            ),
            DetailLine(
              label: 'Extended-state sample',
              value: telemetry.extendedState == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.extendedState!.status)} · ${_mapTimestamp(telemetry.extendedState!.recordedAt)}\nVTOL ${telemetry.extendedState!.vtolState ?? 'unknown'} · Landed ${telemetry.extendedState!.landedState ?? 'unknown'}',
            ),
            DetailLine(
              label: 'GPS sample',
              value: telemetry.gps == null
                  ? 'Missing'
                  : '${displayEnum(telemetry.gps!.status)} · ${_mapTimestamp(telemetry.gps!.recordedAt)}\nFix ${telemetry.gps!.fixType ?? 'unknown'} · ${telemetry.gps!.satellitesVisible ?? 'unknown'} satellites',
            ),
          ],
        ),
      ),
    );
  }
}

String _mapTimestamp(DateTime? timestamp) {
  if (timestamp == null) return 'No sample';
  final delta = DateTime.now().toUtc().difference(timestamp.toUtc());
  final age = delta.isNegative
      ? 'now'
      : delta.inSeconds < 60
      ? '${delta.inSeconds}s ago'
      : delta.inMinutes < 60
      ? '${delta.inMinutes}m ago'
      : '${delta.inHours}h ago';
  return '${formatDate(timestamp)} ($age)';
}

String _mapUnit(double? value, String unit) =>
    value == null ? 'n/a' : '${value.toStringAsFixed(1)} $unit';

void _openAssignedIntent(BuildContext context, AircraftMapView view) {
  final intent = view.activeIntent;
  if (intent == null) return;
  Navigator.of(context).pushNamed(
    '/aircraft/${view.aircraft.id}/intent/new',
    arguments: IntentWorkflowRouteArguments(
      initialIntent: intent,
      initialVolumes: view.operationalVolumes,
    ),
  );
}

void _openCreateIntent(BuildContext context, AircraftMapView view) {
  Navigator.of(context).pushNamed(
    '/aircraft/${view.aircraft.id}/intent/new',
    arguments: IntentWorkflowRouteArguments(
      initialVolumeCenter: mapCenterFor(view),
    ),
  );
}

LatLng mapCenterFor(AircraftMapView view, {AircraftLiveState? liveState}) {
  final livePosition = liveState?.telemetry.position;
  if (livePosition != null) {
    return LatLng(livePosition.latitudeDeg, livePosition.longitudeDeg);
  }
  final telemetry = view.latestTelemetry;
  if (telemetry != null) return telemetryPoint(telemetry);
  if (view.replaySamples.isNotEmpty) {
    return telemetryPoint(view.replaySamples.first);
  }
  final commandedRoute = missionPath(view.validatedMission);
  if (commandedRoute.isNotEmpty) return commandedRoute.first;
  final polygons = volumePolygons(view.operationalVolumes);
  if (polygons.isNotEmpty && polygons.first.isNotEmpty) {
    return polygons.first.first;
  }
  return const LatLng(35.4676, -97.5164);
}

LatLng telemetryPoint(TelemetrySample sample) {
  return LatLng(sample.latitude, sample.longitude);
}

List<LatLng> replayPath(List<TelemetrySample> samples) {
  // The API may return replay samples in store order; the map draws a time-ordered path.
  final sorted = [...samples]
    ..sort((a, b) {
      final left = a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
  return [for (final sample in sorted) telemetryPoint(sample)];
}

double? positionGroundspeed(
  PositionTelemetry position, {
  double? fallbackGroundspeedMps,
}) {
  final north = position.velocityNorthMps;
  final east = position.velocityEastMps;
  if (north != null && east != null) {
    return math.sqrt(north * north + east * east);
  }
  return position.groundspeedMps ?? fallbackGroundspeedMps;
}

/// Returns the current position and a simple constant-velocity projection.
///
/// This is a situational-awareness cue, not a commanded route or mission
/// destination. A projection is omitted when the aircraft is effectively
/// stationary or the API did not provide enough motion information.
List<LatLng> projectedPositionTrack(
  PositionTelemetry position, {
  double? fallbackGroundspeedMps,
  double? fallbackHeadingDeg,
  Duration horizon = const Duration(seconds: 10),
}) {
  var north = position.velocityNorthMps;
  var east = position.velocityEastMps;
  final speed = positionGroundspeed(
    position,
    fallbackGroundspeedMps: fallbackGroundspeedMps,
  );
  if (speed == null || speed < 0.5) return const [];

  if (north == null || east == null) {
    final heading = position.headingDeg ?? fallbackHeadingDeg;
    if (heading == null) return const [];
    final radians = heading * math.pi / 180;
    north = speed * math.cos(radians);
    east = speed * math.sin(radians);
  }

  const metersPerDegreeLatitude = 111320.0;
  final seconds = horizon.inMilliseconds / 1000;
  final latitudeRadians = position.latitudeDeg * math.pi / 180;
  final longitudeScale = metersPerDegreeLatitude * math.cos(latitudeRadians);
  if (longitudeScale.abs() < 1) return const [];

  return [
    LatLng(position.latitudeDeg, position.longitudeDeg),
    LatLng(
      position.latitudeDeg + north * seconds / metersPerDegreeLatitude,
      position.longitudeDeg + east * seconds / longitudeScale,
    ),
  ];
}

List<LatLng> missionPath(Mission? mission) {
  if (mission == null) return const [];
  return [
    for (final item in mission.items) LatLng(item.latitude, item.longitude),
  ];
}

List<int> missionMarkerIndexes(int itemCount, {int maxMarkers = 30}) {
  if (itemCount <= 0 || maxMarkers <= 0) return const [];
  if (itemCount <= maxMarkers) return [for (var i = 0; i < itemCount; i++) i];
  final stride = (itemCount / maxMarkers).ceil();
  final indexes = [for (var i = 0; i < itemCount; i += stride) i];
  if (indexes.last != itemCount - 1) indexes.add(itemCount - 1);
  return indexes;
}

String missionCommandLabel(int command) {
  return switch (command) {
    16 => 'waypoint',
    21 => 'land',
    22 => 'takeoff',
    _ => 'command $command',
  };
}

String _mapShortDigest(String digest) {
  if (digest.length <= 16) return digest;
  return '${digest.substring(0, 8)}…${digest.substring(digest.length - 8)}';
}

List<List<LatLng>> volumePolygons(List<OperationalVolume> volumes) {
  return [
    for (final volume in volumes)
      if ((volume.geoJson ?? '').isNotEmpty)
        ...polygonExteriorRings(volume.geoJson!),
  ];
}

List<List<LatLng>> polygonExteriorRings(String geoJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(geoJson);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic>) return const [];
  final type = decoded['type'];
  Object? coordinates = decoded['coordinates'];
  if (type == 'Feature') {
    final geometry = decoded['geometry'];
    if (geometry is! Map<String, dynamic> || geometry['type'] != 'Polygon') {
      return const [];
    }
    coordinates = geometry['coordinates'];
  } else if (type != 'Polygon') {
    return const [];
  }
  if (coordinates is! List || coordinates.isEmpty) return const [];
  final exterior = coordinates.first;
  if (exterior is! List) return const [];
  final points = <LatLng>[];
  for (final coordinate in exterior) {
    if (coordinate is List && coordinate.length >= 2) {
      final lon = coordinate[0];
      final lat = coordinate[1];
      if (lat is num && lon is num) {
        points.add(LatLng(lat.toDouble(), lon.toDouble()));
      }
    }
  }
  // TODO: render interior rings when the map layer supports holes directly.
  return points.length >= 3 ? [points] : const [];
}
