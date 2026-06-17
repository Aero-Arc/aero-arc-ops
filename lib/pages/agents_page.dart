import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<AircraftListResponse>(
      title: 'Aircraft',
      subtitle:
          'Durable aircraft identity, acceptance, live state, telemetry, maintenance, and readiness.',
      load: AeroArcApiClient().aircraft,
      builder: (context, data) => [
        _FleetMetrics(aircraft: data.aircraft),
        const SizedBox(height: 18),
        _AircraftTable(aircraft: data.aircraft),
        const SizedBox(height: 18),
        TwoColumn(
          left: _LiveStatePanel(aircraft: data.aircraft),
          right: _ReadinessReasonsPanel(aircraft: data.aircraft),
        ),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
              DataColumn(label: Text('Live')),
              DataColumn(label: Text('Readiness')),
            ],
            rows: [
              for (final item in aircraft)
                DataRow(
                  onSelectChanged: (_) => _showAircraftDetails(context, item),
                  cells: [
                    DataCell(
                      Text(
                        item.aircraft.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.aircraft.tailNumber.isEmpty
                            ? item.aircraft.registration ?? 'Not provided'
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
                    DataCell(StatusBadge(label: item.aircraft.remoteIdStatus)),
                    DataCell(
                      Text(formatPercent(item.activeBattery?.stateOfHealth)),
                    ),
                    DataCell(
                      StatusBadge(
                        label: item.liveStateAvailable
                            ? 'connected'
                            : 'offline',
                      ),
                    ),
                    DataCell(StatusBadge(label: item.readiness.status)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatePanel extends StatelessWidget {
  const _LiveStatePanel({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Live State',
      child: RowList(
        children: [
          for (final item in aircraft.take(6))
            ActionRow(
              onTap: () => _showAircraftDetails(context, item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.aircraft.displayName,
                    style: const TextStyle(
                      color: Color(0xFFD6E0FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  DetailLine(
                    label: 'Agent',
                    value:
                        item.liveState?.agentId ??
                        item.aircraft.agentId ??
                        'No live agent',
                  ),
                  DetailLine(
                    label: 'Relay',
                    value: item.liveState?.relayId ?? 'No relay placement',
                  ),
                  DetailLine(
                    label: 'Heartbeat',
                    value: formatDate(item.liveState?.lastHeartbeatAt),
                  ),
                  DetailLine(
                    label: 'Latest telemetry',
                    value: item.latestTelemetry == null
                        ? 'No latest telemetry'
                        : '${item.latestTelemetry!.latitude.toStringAsFixed(5)}, ${item.latestTelemetry!.longitude.toStringAsFixed(5)}',
                  ),
                ],
              ),
            ),
        ],
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
              onTap: () => _showAircraftDetails(context, item),
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

void _showAircraftDetails(BuildContext context, AircraftDashboard item) {
  final aircraft = item.aircraft;
  final battery = item.activeBattery;
  final telemetry = item.latestTelemetry;
  final live = item.liveState;
  showDetailsSheet(
    context,
    title: aircraft.displayName,
    status: StatusBadge(label: item.readiness.status),
    children: [
      detailSection('Why This Aircraft Has This Status', [
        DetailLine(
          label: 'Readiness',
          value: displayEnum(item.readiness.status),
        ),
        DetailLine(
          label: 'Reasons',
          value: item.readiness.reasons.isEmpty
              ? 'No blockers or warnings reported by the API.'
              : item.readiness.reasons.join('\n'),
        ),
        DetailLine(
          label: 'Live state available',
          value: yesNo(item.liveStateAvailable),
        ),
        DetailLine(
          label: 'Open maintenance',
          value:
              '${item.maintenanceEvents.where((e) => e.resolvedAt == null && e.status != 'closed').length}',
        ),
      ]),
      detailSection('Aircraft', [
        DetailLine(label: 'Aircraft ID', value: aircraft.id),
        DetailLine(
          label: 'Tail / registration',
          value:
              '${aircraft.tailNumber} / ${aircraft.registration ?? 'Not provided'}',
        ),
        DetailLine(
          label: 'Model',
          value: '${aircraft.manufacturer} ${aircraft.model}',
        ),
        DetailLine(
          label: 'Serial',
          value: aircraft.serialNumber ?? 'Not provided',
        ),
        DetailLine(
          label: 'Acceptance',
          value: displayEnum(aircraft.acceptanceStatus),
        ),
        DetailLine(
          label: 'Remote ID',
          value:
              '${displayEnum(aircraft.remoteIdStatus)} ${aircraft.remoteIdSerial ?? ''}',
        ),
        DetailLine(
          label: 'Config/software',
          value:
              '${aircraft.configVersion ?? 'No config'} / ${aircraft.softwareVersion ?? 'No software'}',
        ),
      ]),
      detailSection('Battery And Live State', [
        DetailLine(
          label: 'Battery',
          value: battery == null
              ? 'No active battery'
              : '${battery.serialNumber} ${formatPercent(battery.stateOfHealth)} SOH, ${battery.cycleCount} cycles',
        ),
        DetailLine(
          label: 'Battery status',
          value: battery == null ? 'Not provided' : displayEnum(battery.status),
        ),
        DetailLine(
          label: 'Agent',
          value: live?.agentId ?? aircraft.agentId ?? 'No live agent',
        ),
        DetailLine(
          label: 'Relay',
          value: live?.relayId ?? 'No relay placement',
        ),
        DetailLine(
          label: 'Heartbeat',
          value: formatDate(live?.lastHeartbeatAt),
        ),
        DetailLine(
          label: 'Telemetry',
          value: telemetry == null
              ? 'No latest telemetry'
              : '${telemetry.latitude.toStringAsFixed(5)}, ${telemetry.longitude.toStringAsFixed(5)} at ${formatMeters(telemetry.altitudeM)}',
        ),
        DetailLine(
          label: 'Telemetry battery',
          value: formatPercent(telemetry?.batteryPct),
        ),
      ]),
      detailSection('Maintenance Events', [
        if (item.maintenanceEvents.isEmpty)
          const DetailLine(
            label: 'Events',
            value: 'No maintenance events reported.',
          ),
        for (final event in item.maintenanceEvents)
          DetailLine(
            label: event.title,
            value:
                '${displayEnum(event.severity)} / ${displayEnum(event.status)}\n${event.notes}\nOwner: ${event.owner ?? 'Unassigned'}\nDue: ${formatDate(event.dueAt)}',
          ),
      ]),
    ],
  );
}
