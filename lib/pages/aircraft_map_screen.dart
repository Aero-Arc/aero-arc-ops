import 'dart:async';
import 'dart:convert';

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
    this.limit = 1000,
    this.renderTiles = true,
  });

  final String aircraftId;
  final int limit;
  final Future<AircraftMapView> Function()? load;
  final Future<AircraftLiveState> Function()? loadState;
  final bool renderTiles;

  @override
  State<AircraftMapScreen> createState() => _AircraftMapScreenState();
}

class _AircraftMapScreenState extends State<AircraftMapScreen> {
  late Future<AircraftMapView> _future;
  AircraftLiveState? _liveState;
  Object? _liveStateError;
  bool _liveStateLoading = false;
  int _loadGeneration = 0;

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
    _liveStateLoading = stateLoader != null;
    if (stateLoader != null) {
      unawaited(
        _loadLiveState(Future<AircraftLiveState>.sync(stateLoader), generation),
      );
    }
    return mapFuture;
  }

  Future<void> _loadLiveState(
    Future<AircraftLiveState> future,
    int generation,
  ) async {
    final result = await _captureLiveState(future);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _liveState = result.state;
      _liveStateError = result.error;
      _liveStateLoading = false;
    });
  }

  void _refresh() {
    setState(() {
      _liveState = null;
      _liveStateError = null;
      _future = _load();
    });
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

          return _AircraftMapContent(
            view: view,
            liveState: _liveState,
            liveStateError: _liveStateError,
            liveStateLoading: _liveStateLoading,
            onRefresh: _refresh,
            renderTiles: widget.renderTiles,
          );
        },
      ),
    );
  }
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

class _LiveStateResult {
  const _LiveStateResult({this.state, this.error});

  final AircraftLiveState? state;
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
    required this.onRefresh,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final Object? liveStateError;
  final bool liveStateLoading;
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
                    center: center,
                    renderTiles: renderTiles,
                  ),
                  const SizedBox(height: 18),
                  _DetailPanel(
                    view: view,
                    liveState: liveState,
                    liveStateError: liveStateError,
                    liveStateLoading: liveStateLoading,
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
    required this.center,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final LatLng center;
  final bool renderTiles;

  @override
  Widget build(BuildContext context) {
    final path = replayPath(view.replaySamples);
    final polygons = volumePolygons(view.operationalVolumes);
    final livePosition = liveState?.telemetry.position;
    final livePositionAvailable = livePosition?.status == 'fresh';
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
          ),
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
      child: SizedBox(
        height: 560,
        child: FlutterMap(
          key: ValueKey('${center.latitude},${center.longitude}'),
          options: MapOptions(initialCenter: center, initialZoom: 15),
          children: [
            if (renderTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'aero_arc_web',
              ),
            if (polygons.isNotEmpty)
              PolygonLayer(
                polygons: [
                  for (final polygon in polygons)
                    Polygon(
                      points: polygon,
                      color: const Color(0xFF5A6BFF).withValues(alpha: 0.18),
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
                    strokeWidth: 4,
                    color: const Color(0xFF00CFA0),
                  ),
                ],
              ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.view,
    required this.liveState,
    required this.liveStateError,
    required this.liveStateLoading,
  });

  final AircraftMapView view;
  final AircraftLiveState? liveState;
  final Object? liveStateError;
  final bool liveStateLoading;

  @override
  Widget build(BuildContext context) {
    final telemetry = view.latestTelemetry;
    final intent = view.activeIntent;
    final summary = view.conformanceSummary;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                DetailLine(
                  label: 'Status',
                  value: summary == null
                      ? 'No conformance summary.'
                      : displayEnum(summary.status),
                ),
                DetailLine(
                  label: 'Alerts',
                  value:
                      '${summary?.alertCount ?? view.conformanceEvents.length}',
                ),
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
