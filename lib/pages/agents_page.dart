import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key, this.load});

  final Future<AircraftListResponse> Function()? load;

  @override
  Widget build(BuildContext context) {
    return DashboardPage<AircraftListResponse>(
      title: 'Aircraft',
      subtitle:
          'Durable aircraft identity, acceptance, live state, telemetry, maintenance, and readiness.',
      load: load ?? AeroArcApiClient().aircraft,
      builder: (context, data) => [
        _FleetMetrics(aircraft: data.aircraft),
        const SizedBox(height: 18),
        _AircraftTable(aircraft: data.aircraft),
        const SizedBox(height: 18),
        _ReadinessReasonsPanel(aircraft: data.aircraft),
      ],
    );
  }
}

class _FleetMetrics extends StatelessWidget {
  const _FleetMetrics({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    final ready = aircraft.where((a) => a.readiness.status == 'ready').length;
    final live = aircraft.where((a) => a.liveStateAvailable).length;
    final holds = aircraft
        .where(
          (a) => a.maintenanceEvents.any(
            (e) => e.resolvedAt == null && e.status != 'closed',
          ),
        )
        .length;
    final lowBattery = aircraft
        .where((a) => (a.activeBattery?.stateOfHealth ?? 100) < 80)
        .length;
    return MetricGrid(
      metrics: [
        DashboardMetric(
          label: 'Ready aircraft',
          value: '$ready/${aircraft.length}',
          status: 'ready',
        ),
        DashboardMetric(
          label: 'Live state available',
          value: '$live/${aircraft.length}',
          status: live == aircraft.length ? 'ready' : 'warning',
        ),
        DashboardMetric(
          label: 'Maintenance holds',
          value: '$holds',
          status: holds == 0 ? 'ready' : 'warning',
        ),
        DashboardMetric(
          label: 'Low battery SOH',
          value: '$lowBattery',
          status: lowBattery == 0 ? 'ready' : 'warning',
        ),
      ],
    );
  }
}

class _AircraftTable extends StatelessWidget {
  const _AircraftTable({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    if (aircraft.isEmpty) {
      return const EmptyPanel(message: 'No aircraft have been registered yet.');
    }
    return Panel(
      title: 'Fleet Registry',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingTextStyle: const TextStyle(
                    color: Color(0xFF7D8DB4),
                    fontWeight: FontWeight.w600,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Color(0xFFC4D0EE),
                    fontSize: 14,
                  ),
                  columns: const [
                    DataColumn(label: Text('Aircraft')),
                    DataColumn(label: Text('Tail')),
                    DataColumn(label: Text('Model')),
                    DataColumn(label: Text('Acceptance')),
                    DataColumn(label: Text('Remote ID')),
                    DataColumn(label: Text('Battery')),
                    DataColumn(label: Text('Latitude')),
                    DataColumn(label: Text('Longitude')),
                    DataColumn(label: Text('Relay')),
                    DataColumn(label: Text('Last Seen')),
                    DataColumn(label: Text('Readiness')),
                  ],
                  rows: [
                    for (final item in aircraft)
                      DataRow(
                        onSelectChanged: (_) => _openAircraftMap(
                          context,
                          item,
                        ),
                        cells: [
                          DataCell(
                            Text(
                              item.aircraft.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.aircraft.tailNumber.isEmpty
                                  ? item.aircraft.registration ??
                                        'Not provided'
                                  : item.aircraft.tailNumber,
                            ),
                          ),
                          DataCell(
                            Text(
                              item.aircraft.model.isEmpty
                                  ? 'Not provided'
                                  : item.aircraft.model,
                            ),
                          ),
                          DataCell(
                            StatusBadge(label: item.aircraft.acceptanceStatus),
                          ),
                          DataCell(
                            StatusBadge(label: item.aircraft.remoteIdStatus),
                          ),
                          DataCell(
                            Text(
                              formatPercent(item.activeBattery?.stateOfHealth),
                            ),
                          ),
                          DataCell(Text(formatLatitude(item.latestTelemetry))),
                          DataCell(Text(formatLongitude(item.latestTelemetry))),
                          DataCell(
                            Text(
                              item.liveState?.relayId ?? 'No relay placement',
                            ),
                          ),
                          DataCell(_LastSeenBadge(item: item)),
                          DataCell(StatusBadge(label: item.readiness.status)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReadinessReasonsPanel extends StatelessWidget {
  const _ReadinessReasonsPanel({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Readiness Reasons',
      child: RowList(
        children: [
          for (final item
              in aircraft.where((a) => a.readiness.reasons.isNotEmpty).take(8))
            ActionRow(
              onTap: () => _openAircraftMap(context, item),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${item.aircraft.displayName}: ${item.readiness.reasons.join(', ')}',
                      style: const TextStyle(
                        color: Color(0xFFC4D0EE),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: item.readiness.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

void _openAircraftMap(BuildContext context, AircraftDashboard item) {
  Navigator.of(context).pushNamed('/aircraft/${item.aircraft.id}/map');
}

String formatLatitude(TelemetrySample? telemetry) {
  if (telemetry == null) return 'No telemetry';
  return telemetry.latitude.toStringAsFixed(5);
}

String formatLongitude(TelemetrySample? telemetry) {
  if (telemetry == null) return 'No telemetry';
  return telemetry.longitude.toStringAsFixed(5);
}

class _LastSeenBadge extends StatelessWidget {
  const _LastSeenBadge({required this.item});

  final AircraftDashboard item;

  @override
  Widget build(BuildContext context) {
    final label = formatHeartbeatAge(item.liveState);
    final status = lastSeenStatus(item);
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

String lastSeenStatus(AircraftDashboard item) {
  final state = item.liveState;
  if (!item.liveStateAvailable || state == null || !state.connected) {
    return 'offline';
  }
  final heartbeatAge = liveHeartbeatAge(state);
  if (heartbeatAge == null) return 'warning';
  return heartbeatAge < const Duration(seconds: 2) ? 'ready' : 'warning';
}

String formatHeartbeatAge(LiveAircraftState? state) {
  final age = liveHeartbeatAge(state);
  if (age == null) return 'No heartbeat';
  if (age.inSeconds < 60) return '${age.inSeconds}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  return '${age.inHours}h ago';
}

Duration? liveHeartbeatAge(LiveAircraftState? state) {
  final heartbeat = state?.lastHeartbeatAt;
  if (heartbeat == null) return null;
  final age = DateTime.now().difference(heartbeat);
  if (age.isNegative) return Duration.zero;
  return age;
}
