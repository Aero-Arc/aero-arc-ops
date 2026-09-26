import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../pages/aircraft_map_screen.dart'
    show missionPath, missionMarkerIndexes, volumePolygons;
import 'animated_aircraft_position.dart';
import 'dashboard_ui.dart';
import 'open_street_map_basemap.dart';

/// Read-only operational context, bound to an exact intent version. Geometry and
/// live telemetry load independently so an outage cannot erase the stored plan.
class IntentSituationPanel extends StatefulWidget {
  const IntentSituationPanel({
    super.key,
    required this.api,
    required this.intent,
    required this.aircraftId,
    this.initialVolumes = const [],
    this.mission,
    this.renderTiles = true,
    this.onVolumesLoaded,
  });
  final AeroArcApiClient api;
  final OperationalIntent intent;
  final String aircraftId;
  final List<OperationalVolume> initialVolumes;
  final Mission? mission;
  final bool renderTiles;
  final ValueChanged<List<OperationalVolume>>? onVolumesLoaded;

  @override
  State<IntentSituationPanel> createState() => _IntentSituationPanelState();
}

class _IntentSituationPanelState extends State<IntentSituationPanel> {
  final _map = MapController();
  Timer? _timer;
  AircraftLiveState? _live;
  List<OperationalVolume> _volumes = [];
  Mission? _mapMission;
  String? _geometryError, _liveError;
  bool _loading = true, _refreshing = false, _mapReady = false, _fitted = false;
  int _generation = 0;

  bool _matches(OperationalVolume volume) =>
      volume.intentId == widget.intent.id &&
      volume.intentVersion == widget.intent.version;
  bool _missionMatches(Mission? mission) =>
      mission != null &&
      mission.aircraftId == widget.aircraftId &&
      mission.intentId == widget.intent.id &&
      mission.intentVersion == widget.intent.version;

  @override
  void initState() {
    super.initState();
    _volumes = widget.initialVolumes.where(_matches).toList();
    unawaited(_loadGeometry());
    unawaited(_refreshLive());
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshLive()),
    );
  }

  @override
  void didUpdateWidget(covariant IntentSituationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aircraftId != widget.aircraftId ||
        oldWidget.intent.id != widget.intent.id ||
        oldWidget.intent.version != widget.intent.version) {
      _generation++;
      _volumes = widget.initialVolumes.where(_matches).toList();
      _mapMission = null;
      _live = null;
      _geometryError = null;
      _liveError = null;
      _fitted = false;
      _loading = true;
      _refreshing = false;
      unawaited(_loadGeometry());
      unawaited(_refreshLive());
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadGeometry() async {
    final generation = _generation;
    if (mounted) setState(() => _loading = true);
    try {
      final view = await widget.api.getAircraftMapView(
        widget.aircraftId,
        limit: 200,
      );
      if (!mounted || generation != _generation) return;
      if (view.aircraft.id != widget.aircraftId ||
          view.activeIntent?.id != widget.intent.id ||
          view.activeIntent?.version != widget.intent.version) {
        throw const AeroArcApiException(
          'The map does not contain this intent version. Its geometry has not been substituted with another operation.',
        );
      }
      final volumes = view.operationalVolumes.where(_matches).toList();
      setState(() {
        _volumes = volumes;
        _mapMission = _missionMatches(view.validatedMission)
            ? view.validatedMission
            : null;
        _geometryError = volumes.isEmpty
            ? 'No saved geometry is available for this intent version.'
            : null;
      });
      if (volumes.isNotEmpty) widget.onVolumesLoaded?.call(volumes);
      _fitOnce();
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _geometryError = 'Saved geometry unavailable: $e');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitOnce();
      });
    }
  }

  Future<void> _refreshLive() async {
    if (_refreshing) return;
    _refreshing = true;
    final generation = _generation;
    try {
      final live = await widget.api.getAircraftState(widget.aircraftId);
      if (!mounted || generation != _generation) return;
      if (live.aircraftId != widget.aircraftId) {
        throw const AeroArcApiException('Aircraft state identity mismatch');
      }
      setState(() {
        _live = live;
        _liveError = null;
      });
      _fitOnce();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _liveError =
              'Live state unavailable · retaining the last received position',
        );
      }
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Mission? get _mission =>
      _missionMatches(widget.mission) ? widget.mission : _mapMission;
  List<LatLng> get _fitPoints => [
    ...volumePolygons(_volumes).expand((ring) => ring),
    ...missionPath(_mission),
    if (_live?.telemetry.position case final position?)
      LatLng(position.latitudeDeg, position.longitudeDeg),
  ];
  void _fitOnce() {
    if (!_fitted && _mapReady && !_loading && _fitPoints.isNotEmpty) {
      _fit();
      _fitted = true;
    }
  }

  void _fit() {
    if (!_mapReady || _fitPoints.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_fitPoints),
        padding: const EdgeInsets.all(44),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polygons = volumePolygons(_volumes);
    final route = missionPath(_mission);
    final position = _live?.telemetry.position;
    final fresh = _liveError == null && position?.status == 'fresh';
    final vehicle = _live?.telemetry.vehicle;
    final points = _fitPoints;
    return Panel(
      title: 'Operation map',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Fit operation',
            onPressed: points.isEmpty ? null : _fit,
            icon: const Icon(Icons.center_focus_strong, size: 18),
          ),
          IconButton(
            tooltip: 'Refresh operation map',
            onPressed: _loading
                ? null
                : () {
                    unawaited(_loadGeometry());
                    unawaited(_refreshLive());
                  },
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _legend(
                  'Intent boundary · v${widget.intent.version}',
                  const Color(0xFF8194FF),
                ),
                _legend(
                  'Mission · ${route.length} points',
                  const Color(0xFFF1BD64),
                ),
                _legend(
                  position == null
                      ? 'Position unavailable'
                      : fresh
                      ? 'Live aircraft'
                      : 'Last known aircraft',
                  fresh ? const Color(0xFF16C8E0) : const Color(0xFF8797AB),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          SizedBox(
            height: 360,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: points.isEmpty
                        ? const LatLng(0, 0)
                        : points.first,
                    initialZoom: points.isEmpty ? 2 : 15,
                    onMapReady: () {
                      _mapReady = true;
                      _fitOnce();
                    },
                  ),
                  children: [
                    if (widget.renderTiles) const OpenStreetMapBasemap(),
                    PolygonLayer(
                      polygons: [
                        for (final ring in polygons)
                          Polygon(
                            points: ring,
                            color: const Color(
                              0xFF8194FF,
                            ).withValues(alpha: 0.14),
                            borderColor: const Color(0xFF8194FF),
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    if (route.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route,
                            color: const Color(0xFFF1BD64),
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final ring in polygons)
                          for (var i = 0; i < ring.length - 1; i++)
                            Marker(
                              point: ring[i],
                              width: 10,
                              height: 10,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFF8194FF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        for (final i in missionMarkerIndexes(route.length))
                          Marker(
                            point: route[i],
                            width: 24,
                            height: 24,
                            child: Tooltip(
                              message: 'Mission point ${i + 1}',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16232E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF1BD64),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFF1BD64),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (position != null)
                      AnimatedAircraftPosition(
                        point: LatLng(
                          position.latitudeDeg,
                          position.longitudeDeg,
                        ),
                        heading: position.headingDeg ?? 0,
                        recordedAt: position.recordedAt,
                        fresh: fresh,
                        builder: (context, point, heading) => MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 40,
                              height: 40,
                              child: Tooltip(
                                message: fresh
                                    ? 'Live aircraft position'
                                    : 'Last known aircraft position',
                                child: Transform.rotate(
                                  angle: heading * math.pi / 180,
                                  child: Icon(
                                    Icons.navigation,
                                    color: fresh
                                        ? const Color(0xFF16C8E0)
                                        : const Color(0xFF8797AB),
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.renderTiles) const OpenStreetMapAttribution(),
                  ],
                ),
                if (!_loading && points.isEmpty)
                  const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Waiting for saved geometry or aircraft position',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 22,
                  runSpacing: 8,
                  children: [
                    _reading(
                      'POSITION · ${_liveError != null ? 'unavailable' : position?.status ?? 'missing'}',
                      position == null
                          ? 'No sample'
                          : '${position.latitudeDeg.toStringAsFixed(5)}, ${position.longitudeDeg.toStringAsFixed(5)}',
                      position?.recordedAt,
                    ),
                    _reading(
                      'ALTITUDE · RELATIVE',
                      position?.relativeAltitudeM == null
                          ? 'Not reported'
                          : '${position!.relativeAltitudeM!.toStringAsFixed(1)} m',
                      position?.recordedAt,
                    ),
                    _reading(
                      'VEHICLE · ${_liveError != null ? 'unavailable' : vehicle?.status ?? 'missing'}',
                      vehicle?.armed == null
                          ? 'Not reported'
                          : '${vehicle!.armed! ? 'Armed' : 'Disarmed'} · mode ${vehicle.customMode ?? 'unknown'}',
                      vehicle?.recordedAt,
                    ),
                  ],
                ),
                if (_geometryError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _geometryError!,
                      style: const TextStyle(
                        color: Color(0xFFF1BD64),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (_liveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _liveError!,
                      style: const TextStyle(
                        color: Color(0xFF8797AB),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 7, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFFB3C0D0)),
      ),
    ],
  );
  Widget _reading(String label, String value, DateTime? at) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF8797AB),
          letterSpacing: .7,
        ),
      ),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 12)),
      if (at != null)
        Text(
          formatDate(at),
          style: const TextStyle(fontSize: 10, color: Color(0xFF8797AB)),
        ),
    ],
  );
}
