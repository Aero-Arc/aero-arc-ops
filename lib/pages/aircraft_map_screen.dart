import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class AircraftMapScreen extends StatefulWidget {
  const AircraftMapScreen({
    super.key,
    required this.aircraftId,
    this.load,
    this.limit = 1000,
    this.renderTiles = true,
  });

  final String aircraftId;
  final int limit;
  final Future<AircraftMapView> Function()? load;
  final bool renderTiles;

  @override
  State<AircraftMapScreen> createState() => _AircraftMapScreenState();
}

class _AircraftMapScreenState extends State<AircraftMapScreen> {
  late Future<AircraftMapView> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AircraftMapView> _load() {
    final custom = widget.load;
    if (custom != null) return custom();
    return AeroArcApiClient().getAircraftMapView(
      widget.aircraftId,
      limit: widget.limit,
    );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: aeroPageGradient),
      child: FutureBuilder<AircraftMapView>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 24),
              child: LoadingPanel(),
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
            onRefresh: _refresh,
            renderTiles: widget.renderTiles,
          );
        },
      ),
    );
  }
}

class _AircraftMapContent extends StatelessWidget {
  const _AircraftMapContent({
    required this.view,
    required this.onRefresh,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final VoidCallback onRefresh;
  final bool renderTiles;

  @override
  Widget build(BuildContext context) {
    final center = mapCenterFor(view);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MapHeader(view: view, onRefresh: onRefresh),
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
                        center: center,
                        renderTiles: renderTiles,
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(width: 390, child: _DetailPanel(view: view)),
                  ],
                );
              }
              return Column(
                children: [
                  _MapPanel(
                    view: view,
                    center: center,
                    renderTiles: renderTiles,
                  ),
                  const SizedBox(height: 18),
                  _DetailPanel(view: view),
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
  const _MapHeader({required this.view, required this.onRefresh});

  final AircraftMapView view;
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
                    label: view.liveStateAvailable ? 'connected' : 'offline',
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
    required this.center,
    required this.renderTiles,
  });

  final AircraftMapView view;
  final LatLng center;
  final bool renderTiles;

  @override
  Widget build(BuildContext context) {
    final path = replayPath(view.replaySamples);
    final polygons = volumePolygons(view.operationalVolumes);
    final livePositionAvailable =
        view.liveStateAvailable && (view.liveState?.connected ?? false);
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
      if (view.latestTelemetry != null)
        Marker(
          point: telemetryPoint(view.latestTelemetry!),
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
  const _DetailPanel({required this.view});

  final AircraftMapView view;

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
        Panel(
          title: 'Operation',
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
                  value: formatPercent(telemetry?.batteryPct),
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

LatLng mapCenterFor(AircraftMapView view) {
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
