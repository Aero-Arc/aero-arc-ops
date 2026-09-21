import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';
import '../widgets/open_street_map_basemap.dart';
import '../widgets/animated_aircraft_position.dart';
import 'aircraft_map_screen.dart'
    show missionPath, volumePolygons, projectedPositionTrack, replayPath;

const _cyan = Color(0xFF16C8E0);
const _muted = Color(0xFF8797AB);

/// Fleet overview uses one batch request, preserving each telemetry group's age.
class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    this.load,
    this.loadMap,
    this.renderTiles = true,
  });
  final Future<OperationsDashboard> Function()? load;
  final Future<AircraftMapView> Function(String aircraftId)? loadMap;
  final bool renderTiles;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final _map = MapController();
  String? _selected;
  String _filter = 'All';
  bool _aircraftLayer = true;
  bool _missionLayer = true;
  bool _volumeLayer = true;
  AircraftMapView? _selectedMap;
  String? _mapError;
  int _selectionVersion = 0;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  void _select(String id, OperationsDashboard data) {
    final version = ++_selectionVersion;
    setState(() {
      _selected = id;
      _selectedMap = null;
      _mapError = null;
    });
    final loader =
        widget.loadMap ??
        (widget.load == null
            ? (String id) => AeroArcApiClient().getAircraftMapView(id)
            : null);
    if (loader != null) {
      Future.sync(() => loader(id)).then(
        (view) {
          if (mounted && version == _selectionVersion) {
            setState(() => _selectedMap = view);
          }
        },
        onError: (Object error) {
          if (mounted && version == _selectionVersion) {
            setState(
              () => _mapError =
                  'Mission layers unavailable · select aircraft to retry',
            );
          }
        },
      );
    }
    final state = data.liveAircraft
        .where((s) => s.aircraftId == id)
        .firstOrNull;
    final p = state?.telemetry.position;
    if (p != null) _map.move(LatLng(p.latitudeDeg, p.longitudeDeg), 14);
    if (state == null) {
      final intent = data.operationalIntents
          .where((i) => i.aircraftId == id)
          .firstOrNull;
      showDetailsSheet(
        context,
        title: intent?.name ?? id,
        children: [
          DetailLine(label: 'Aircraft', value: id),
          DetailLine(label: 'Intent', value: intent?.status ?? 'Unknown'),
          const DetailLine(label: 'Telemetry', value: 'Unavailable'),
          OutlinedButton(
            onPressed: () => _open('/aircraft/$id/map'),
            child: const Text('Open aircraft workspace'),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) => DashboardPage<OperationsDashboard>(
    title: 'Overview',
    subtitle: 'Current operations · Fleet, missions, and airspace',
    load: widget.load ?? AeroArcApiClient().operations,
    autoRefreshInterval: const Duration(seconds: 1),
    builder: (context, data) {
      final active = data.operationalIntents
          .where(
            (i) => const {
              'active',
              'activated',
              'contingent',
              'non_conforming',
            }.contains(i.status),
          )
          .toList();
      final online = data.liveAircraft
          .where((s) => s.connection.status == 'connected')
          .length;
      final attention = data.conformance
          .where(
            (c) =>
                c.alertCount > 0 ||
                c.activeViolationCount > 0 ||
                const {
                  'warning',
                  'non_conforming',
                  'violation',
                  'degraded',
                }.contains(c.condition ?? c.status),
          )
          .toList();
      final selected = data.liveAircraft
          .where((s) => s.aircraftId == _selected)
          .firstOrNull;
      return [
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 1,
            runSpacing: 1,
            children: [
              for (final item in <(String, String, IconData, String)>[
                (
                  'ACTIVE INTENTS',
                  '${active.length}',
                  Icons.route,
                  '/operations',
                ),
                (
                  'AIRCRAFT ONLINE',
                  '$online / ${data.liveAircraft.length}',
                  Icons.flight,
                  '/aircraft',
                ),
                (
                  'CONFORMANCE',
                  data.conformance.isEmpty
                      ? 'Unknown'
                      : '${attention.length} need review',
                  Icons.verified_user_outlined,
                  '/conformance',
                ),
                (
                  'AIRSPACE CONFLICTS',
                  'Unknown',
                  Icons.layers_outlined,
                  '/operations',
                ),
                (
                  'CONFORMANCE ALERTS',
                  data.conformance.isEmpty
                      ? 'Unknown'
                      : '${data.conformance.fold<int>(0, (n, c) => n + c.alertCount)}',
                  Icons.notifications_outlined,
                  '/conformance',
                ),
              ])
                SizedBox(
                  height: box.maxWidth < 700 ? 100 : 82,
                  width:
                      (box.maxWidth - (box.maxWidth < 700 ? 1 : 4)) /
                      (box.maxWidth < 700 ? 2 : 5),
                  child: Material(
                    color: const Color(0xFF101720),
                    child: InkWell(
                      onTap: () => _open(item.$4),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(item.$3, color: _cyan, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: item.$2 == 'Unknown'
                                          ? _muted
                                          : (item.$1 == 'CONFORMANCE' ||
                                                    item.$1 ==
                                                        'CONFORMANCE ALERTS') &&
                                                attention.isNotEmpty
                                          ? const Color(0xFFE7AC38)
                                          : _cyan,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final map = _mapPanel(data);
            final missions = _missions(data, active);
            if (box.maxWidth < 850) {
              return Column(
                children: [
                  map,
                  const SizedBox(height: 16),
                  missions,
                  if (selected != null) ...[
                    const SizedBox(height: 16),
                    _inspector(selected, data),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: map),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: selected == null
                      ? missions
                      : _inspector(selected, data),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        TwoColumn(
          breakpoint: 850,
          left: _timeline(data),
          right: _alerts(attention),
        ),
        const SizedBox(height: 16),
        _fleet(data),
        const SizedBox(height: 16),
        TwoColumn(
          breakpoint: 850,
          left: Panel(
            title: 'Airspace',
            trailing: TextButton(
              onPressed: () => _open('/operations'),
              child: const Text('Open workspace →'),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DetailLine(
                    label: 'Active intents',
                    value: '${active.length}',
                  ),
                  const DetailLine(
                    label: 'DSS / peers',
                    value: 'Unknown · feed not available',
                  ),
                  const DetailLine(
                    label: 'Restrictions',
                    value: 'NOTAM and airspace feeds unavailable',
                  ),
                ],
              ),
            ),
          ),
          right: Panel(
            title: 'Conformance',
            trailing: TextButton(
              onPressed: () => _open('/conformance'),
              child: const Text('Open workspace →'),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DetailLine(
                    label: 'Evaluations',
                    value: '${data.conformance.length}',
                  ),
                  DetailLine(
                    label: 'Need attention',
                    value: '${attention.length}',
                  ),
                  const DetailLine(
                    label: 'History',
                    value: 'Open workspace for recorded evidence',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Infrastructure',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final service in [
                  'API',
                  'Registry',
                  'Relay',
                  'Agent Fleet',
                  'Conformance Worker',
                  'DSS',
                  'PostGIS',
                  'Event Bus',
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: service == 'API' ? _cyan : _muted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '$service · ${service == 'API' ? 'Responding' : 'Unknown'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ];
    },
  );

  Widget _mapPanel(OperationsDashboard data) {
    final positioned = data.liveAircraft
        .where((s) => s.telemetry.position != null)
        .toList();
    final points = positioned
        .map(
          (s) => LatLng(
            s.telemetry.position!.latitudeDeg,
            s.telemetry.position!.longitudeDeg,
          ),
        )
        .toList();
    void center() {
      if (points.length == 1) {
        _map.move(points.first, 14);
      } else if (points.isNotEmpty) {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(60),
            maxZoom: 15,
          ),
        );
      }
    }

    return Panel(
      title: 'Live operations map',
      trailing: PopupMenuButton<String>(
        tooltip: 'Map layers',
        icon: const Icon(Icons.layers_outlined, color: _cyan, size: 18),
        onSelected: (layer) => setState(() {
          if (layer == 'aircraft') _aircraftLayer = !_aircraftLayer;
          if (layer == 'missions') _missionLayer = !_missionLayer;
          if (layer == 'volumes') _volumeLayer = !_volumeLayer;
        }),
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'aircraft',
            checked: _aircraftLayer,
            child: const Text('Aircraft'),
          ),
          CheckedPopupMenuItem(
            value: 'missions',
            checked: _missionLayer,
            child: const Text('Missions · selected aircraft'),
          ),
          CheckedPopupMenuItem(
            value: 'volumes',
            checked: _volumeLayer,
            child: const Text('Operational volumes · selected aircraft'),
          ),
          for (final name in [
            'Peer operations',
            'NOTAMs',
            'Controlled airspace',
            'Geofences',
            'Weather',
          ])
            PopupMenuItem<String>(
              enabled: false,
              child: Text('$name · unavailable'),
            ),
        ],
      ),
      child: SizedBox(
        height: 460,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter:
                      points.firstOrNull ?? const LatLng(29.76, -95.37),
                  initialZoom: points.isEmpty ? 10 : 13,
                  backgroundColor: const Color(0xFF0B1118),
                ),
                children: [
                  if (widget.renderTiles) const OpenStreetMapBasemap(),
                  if (_volumeLayer && _selectedMap != null)
                    PolygonLayer(
                      polygons: [
                        for (final polygon in volumePolygons(
                          _selectedMap!.operationalVolumes,
                        ))
                          Polygon(
                            points: polygon,
                            color: _cyan.withValues(alpha: .08),
                            borderColor: _cyan.withValues(alpha: .6),
                            borderStrokeWidth: 1,
                          ),
                      ],
                    ),
                  if (_missionLayer && _selectedMap != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: missionPath(_selectedMap!.validatedMission),
                          color: _cyan.withValues(alpha: .5),
                          strokeWidth: 2,
                          pattern: const StrokePattern.dotted(),
                        ),
                        Polyline(
                          points: replayPath(_selectedMap!.replaySamples),
                          color: _cyan,
                          strokeWidth: 2,
                        ),
                      ],
                    ),
                  if (_missionLayer)
                    PolylineLayer(
                      polylines: [
                        for (final s in positioned)
                          if (s.telemetry.position!.status == 'fresh')
                            Polyline(
                              points: projectedPositionTrack(
                                s.telemetry.position!,
                              ),
                              color: const Color(0xFF21C997),
                              strokeWidth: 1,
                              pattern: const StrokePattern.dotted(),
                            ),
                      ],
                    ),
                  if (_missionLayer && _selectedMap?.validatedMission != null)
                    MarkerLayer(
                      markers: [
                        for (final item
                            in _selectedMap!.validatedMission!.items)
                          Marker(
                            point: LatLng(item.latitude, item.longitude),
                            width: 18,
                            height: 18,
                            child: Tooltip(
                              message: 'Waypoint ${item.sequence}',
                              child: const Icon(
                                Icons.circle_outlined,
                                size: 8,
                                color: _cyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (_aircraftLayer)
                    for (final s in positioned)
                      AnimatedAircraftPosition(
                        key: ValueKey(s.aircraftId),
                        point: LatLng(
                          s.telemetry.position!.latitudeDeg,
                          s.telemetry.position!.longitudeDeg,
                        ),
                        heading: s.telemetry.position!.headingDeg ?? 0,
                        recordedAt: s.telemetry.position!.recordedAt,
                        fresh: s.telemetry.position!.status == 'fresh',
                        builder: (context, point, heading) => MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 110,
                              height: 64,
                              child: GestureDetector(
                                onTap: () => _select(s.aircraftId, data),
                                child: Column(
                                  children: [
                                    Transform.rotate(
                                      angle: heading * math.pi / 180,
                                      child: Icon(
                                        Icons.navigation,
                                        size: s.aircraftId == _selected
                                            ? 30
                                            : 22,
                                        color: statusColor(
                                          s.telemetry.position!.status,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: const Color(0xDD101720),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        s.aircraftId,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xEE101720),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _mapError ??
                        '${positioned.length} located aircraft · refresh 1s',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ),
              if (points.isEmpty)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Awaiting aircraft position telemetry',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 32,
                left: 12,
                child: Material(
                  color: const Color(0xFF101720),
                  borderRadius: BorderRadius.circular(6),
                  child: Column(
                    children: [
                      IconButton(
                        tooltip: 'Zoom in',
                        onPressed: () => _map.move(
                          _map.camera.center,
                          (_map.camera.zoom + 1).clamp(2, 19),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Zoom out',
                        onPressed: () => _map.move(
                          _map.camera.center,
                          (_map.camera.zoom - 1).clamp(2, 19),
                        ),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Center active fleet',
                        onPressed: points.isEmpty ? null : center,
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const OpenStreetMapAttribution(),
              if (_selectedMap != null)
                const Positioned(
                  right: 12,
                  bottom: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xEE101720)),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Selected mission snapshot\n·· Planned   ─ Flown   ·· Projected (10s)',
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missions(OperationsDashboard data, List<OperationalIntent> active) =>
      Panel(
        title: 'Active missions',
        trailing: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(
            '${active.length} intents',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        child: SizedBox(
          height: 460,
          child: active.isEmpty
              ? const Center(
                  child: Text(
                    'No active operational intents',
                    style: TextStyle(color: _muted),
                  ),
                )
              : ListView.separated(
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final i = active[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onTap: () => _select(i.aircraftId, data),
                      title: Text(
                        i.name.isEmpty ? i.id : i.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            i.aircraftId,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 12),
                          StatusBadge(label: i.status),
                          const SizedBox(height: 8),
                          const Text(
                            'Mission progress unavailable',
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      );

  Widget _inspector(AircraftLiveState s, OperationsDashboard data) {
    final t = s.telemetry;
    final intent = data.operationalIntents
        .where((i) => i.aircraftId == s.aircraftId)
        .firstOrNull;
    final c = data.conformance
        .where((i) => i.aircraftId == s.aircraftId)
        .firstOrNull;
    String value(num? n, String unit) =>
        n == null ? 'Unknown' : '${n.toStringAsFixed(1)} $unit';
    Widget group(
      String title,
      TelemetryGroup? group,
      List<Widget> values,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(
          title,
          style: const TextStyle(color: _cyan, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          '${displayEnum(group?.status ?? 'missing')} · ${formatDate(group?.recordedAt)}',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        ...values,
      ],
    );
    return Panel(
      title: s.aircraftId,
      trailing: IconButton(
        tooltip: 'Close inspector',
        onPressed: () => setState(() {
          _selected = null;
          _selectedMap = null;
          _mapError = null;
          _selectionVersion++;
        }),
        icon: const Icon(Icons.close, size: 18),
      ),
      child: SizedBox(
        height: 460,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusBadge(label: s.connection.status),
            const SizedBox(height: 12),
            Text(
              intent?.name ?? 'No assigned intent',
              style: const TextStyle(fontSize: 13),
            ),
            group('POSITION', t.position, [
              DetailLine(
                label: 'Altitude MSL',
                value: value(t.position?.altitudeMslM, 'm'),
              ),
              DetailLine(
                label: 'Ground speed',
                value: value(t.position?.groundspeedMps, 'm/s'),
              ),
              DetailLine(
                label: 'Heading',
                value: value(t.position?.headingDeg, '°'),
              ),
            ]),
            group('BATTERY', t.battery, [
              DetailLine(
                label: 'Remaining',
                value: value(t.battery?.remainingPct, '%'),
              ),
            ]),
            group('GPS', t.gps, [
              DetailLine(label: 'Fix', value: t.gps?.fixType ?? 'Unknown'),
              DetailLine(
                label: 'Satellites',
                value: '${t.gps?.satellitesVisible ?? 'Unknown'}',
              ),
            ]),
            group('FLIGHT', t.hud, [
              DetailLine(
                label: 'Vertical speed',
                value: value(t.hud?.climbRateMps, 'm/s'),
              ),
            ]),
            const Divider(),
            DetailLine(
              label: 'Agent',
              value: s.connection.agentId ?? 'Unmapped',
            ),
            DetailLine(
              label: 'Relay placement',
              value: s.connection.relayId ?? 'Unknown',
            ),
            DetailLine(
              label: 'Conformance',
              value: c?.condition ?? c?.status ?? 'Unknown',
            ),
            DetailLine(
              label: 'Monitoring',
              value: c?.monitoringStatus ?? 'Unknown',
            ),
            OutlinedButton(
              onPressed: () => _open('/aircraft/${s.aircraftId}/map'),
              child: const Text('Open mission & flight controls'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(OperationsDashboard data) {
    final updates =
        <({DateTime time, String category, String title, String aircraftId})>[
          for (final i in data.operationalIntents)
            if (i.updatedAt != null)
              (
                time: i.updatedAt!,
                category: 'Airspace',
                title:
                    '${i.name.isEmpty ? i.id : i.name} · ${displayEnum(i.status)}',
                aircraftId: i.aircraftId,
              ),
          for (final c in data.conformance)
            if (c.observedAt != null || c.updatedAt != null)
              (
                time: c.observedAt ?? c.updatedAt!,
                category: 'Conformance',
                title:
                    '${c.aircraftId} · ${displayEnum(c.condition ?? c.status)}',
                aircraftId: c.aircraftId,
              ),
        ]..sort((a, b) => b.time.compareTo(a.time));
    final visible = updates.where(
      (u) => _filter == 'All' || u.category == _filter,
    );
    return Panel(
      title: 'Latest operational updates',
      child: SizedBox(
        height: 240,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    for (final filter in ['All', 'Airspace', 'Conformance'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        'No updates in this category',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final u in visible.take(20))
                          ListTile(
                            dense: true,
                            leading: Icon(
                              u.category == 'Airspace'
                                  ? Icons.route
                                  : Icons.verified_user_outlined,
                              color: _cyan,
                              size: 16,
                            ),
                            title: Text(
                              u.title,
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              '${formatDate(u.time)} · ${u.category}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                            onTap: () => _select(u.aircraftId, data),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alerts(List<ConformanceSummary> attention) => Panel(
    title: 'Alerts',
    trailing: TextButton(
      onPressed: () => _open('/conformance'),
      child: const Text('Review →'),
    ),
    child: SizedBox(
      height: 240,
      child: attention.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No conformance alerts reported.\nOther alert sources are not connected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            )
          : ListView(
              children: [
                for (final c in attention)
                  ListTile(
                    leading: const Icon(
                      Icons.warning_amber,
                      color: Color(0xFFE7AC38),
                      size: 18,
                    ),
                    title: Text(
                      '${c.aircraftId} · ${displayEnum(c.condition ?? c.status)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${c.alertCount} alerts · Monitoring ${c.monitoringStatus ?? 'unknown'}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    onTap: () => _open('/conformance'),
                  ),
              ],
            ),
    ),
  );

  Widget _fleet(OperationsDashboard data) => Panel(
    title: 'Fleet health',
    child: data.liveAircraft.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No aircraft reported. Connect an aircraft to begin monitoring.',
              style: TextStyle(color: _muted),
            ),
          )
        : LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columnSpacing: 24,
                  showCheckboxColumn: false,
                  columns: [
                    for (final title in [
                      'AIRCRAFT',
                      'CONNECTION',
                      'MISSION',
                      'AGENT',
                      'RELAY',
                      'TELEMETRY',
                      'BATTERY',
                      'GPS',
                      'LAST SEEN',
                    ])
                      DataColumn(
                        label: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _muted,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                  ],
                  rows: [
                    for (final s in data.liveAircraft)
                      DataRow(
                        selected: _selected == s.aircraftId,
                        onSelectChanged: (_) => _select(s.aircraftId, data),
                        cells: [
                          DataCell(
                            Text(
                              s.aircraftId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataCell(StatusBadge(label: s.connection.status)),
                          DataCell(
                            Text(
                              data.operationalIntents
                                      .where(
                                        (i) => i.aircraftId == s.aircraftId,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  '—',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              s.connection.agentId == null
                                  ? 'Unmapped'
                                  : displayEnum(s.connection.status),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              s.connection.relayId ?? 'Unknown',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(StatusBadge(label: s.telemetry.status)),
                          DataCell(
                            Text(
                              s.telemetry.battery == null
                                  ? 'Unknown'
                                  : '${s.telemetry.battery!.remainingPct?.toStringAsFixed(0) ?? '—'}% · ${s.telemetry.battery!.status}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              s.telemetry.gps == null
                                  ? 'Unknown'
                                  : '${s.telemetry.gps!.fixType ?? 'Unknown'} · ${s.telemetry.gps!.status}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              formatDate(s.telemetry.lastObservedAt),
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
  );
}
