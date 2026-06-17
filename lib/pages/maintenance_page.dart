import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<MaintenanceDashboard>(
      title: 'Maintenance',
      subtitle:
          'Maintenance irregularities, battery lifecycle, owners, due dates, and return-to-service evidence.',
      load: AeroArcApiClient().maintenance,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _MaintenanceTable(events: data.events),
        const SizedBox(height: 18),
        TwoColumn(
          left: _BatteryPanel(batteries: data.batteries),
          right: _ReturnToServicePanel(events: data.events),
        ),
      ],
    );
  }
}

class _MaintenanceTable extends StatelessWidget {
  const _MaintenanceTable({required this.events});

  final List<MaintenanceEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyPanel(message: 'No maintenance events are available.');
    }
    return Panel(
      title: 'Maintenance Control',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Event')),
              DataColumn(label: Text('Severity')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Owner')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('RTS')),
            ],
            rows: [
              for (final event in events)
                DataRow(
                  onSelectChanged: (_) =>
                      _showMaintenanceDetails(context, event),
                  cells: [
                    DataCell(
                      Text(
                        event.aircraftId,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(event.title)),
                    DataCell(StatusBadge(label: event.severity)),
                    DataCell(StatusBadge(label: event.status)),
                    DataCell(Text(event.owner ?? 'Unassigned')),
                    DataCell(Text(formatDate(event.dueAt))),
                    DataCell(
                      Text(
                        event.returnToServiceAt == null
                            ? 'Pending'
                            : formatDate(event.returnToServiceAt),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryPanel extends StatelessWidget {
  const _BatteryPanel({required this.batteries});

  final List<Battery> batteries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Battery Health',
      child: RowList(
        children: [
          for (final battery in batteries.take(10))
            ActionRow(
              onTap: () => _showBatteryDetails(context, battery),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          battery.serialNumber.isEmpty
                              ? battery.id
                              : battery.serialNumber,
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${battery.model} - ${battery.cycleCount} cycles',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatPercent(battery.stateOfHealth),
                    style: TextStyle(
                      color: statusColor(battery.status),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: battery.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReturnToServicePanel extends StatelessWidget {
  const _ReturnToServicePanel({required this.events});

  final List<MaintenanceEvent> events;

  @override
  Widget build(BuildContext context) {
    final pending = events
        .where(
          (event) =>
              event.resolvedAt == null || event.returnToServiceAt == null,
        )
        .toList();
    return Panel(
      title: 'Return to Service',
      child: RowList(
        children: [
          for (final event in pending.take(8))
            ActionRow(
              onTap: () => _showMaintenanceDetails(context, event),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      StatusBadge(label: event.severity),
                    ],
                  ),
                  DetailLine(label: 'Aircraft', value: event.aircraftId),
                  DetailLine(label: 'Notes', value: event.notes),
                  DetailLine(
                    label: 'Corrective action',
                    value: event.correctiveAction ?? 'Not provided',
                  ),
                  DetailLine(
                    label: 'RTS by',
                    value: event.returnToServiceBy ?? 'Not signed off',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

void _showMaintenanceDetails(BuildContext context, MaintenanceEvent event) {
  showDetailsSheet(
    context,
    title: event.title,
    status: StatusBadge(label: event.severity),
    children: [
      detailSection('Dispatch Impact', [
        DetailLine(label: 'Status', value: displayEnum(event.status)),
        DetailLine(label: 'Severity', value: displayEnum(event.severity)),
        DetailLine(label: 'Aircraft', value: event.aircraftId),
        DetailLine(
          label: 'Linked intent',
          value: event.intentId ?? 'Not linked',
        ),
        DetailLine(label: 'Due', value: formatDate(event.dueAt)),
      ]),
      detailSection('Maintenance Detail', [
        DetailLine(label: 'Event ID', value: event.id),
        DetailLine(label: 'Type', value: event.eventType ?? 'Not provided'),
        DetailLine(label: 'Notes', value: event.notes),
        DetailLine(label: 'Owner', value: event.owner ?? 'Unassigned'),
        DetailLine(label: 'Opened', value: formatDate(event.openedAt)),
        DetailLine(label: 'Resolved', value: formatDate(event.resolvedAt)),
      ]),
      detailSection('Return To Service', [
        DetailLine(
          label: 'Corrective action',
          value: event.correctiveAction ?? 'Not provided',
        ),
        DetailLine(
          label: 'RTS time',
          value: formatDate(event.returnToServiceAt),
        ),
        DetailLine(
          label: 'RTS by',
          value: event.returnToServiceBy ?? 'Not signed off',
        ),
      ]),
    ],
  );
}

void _showBatteryDetails(BuildContext context, Battery battery) {
  showDetailsSheet(
    context,
    title: battery.serialNumber.isEmpty ? battery.id : battery.serialNumber,
    status: StatusBadge(label: battery.status),
    children: [
      detailSection('Battery Health', [
        DetailLine(label: 'Battery ID', value: battery.id),
        DetailLine(label: 'Model', value: battery.model),
        DetailLine(
          label: 'State of health',
          value: formatPercent(battery.stateOfHealth),
        ),
        DetailLine(label: 'Cycles', value: '${battery.cycleCount}'),
        DetailLine(label: 'Status', value: displayEnum(battery.status)),
        DetailLine(
          label: 'Manufactured',
          value: formatDate(battery.manufacturedAt),
        ),
        DetailLine(label: 'Updated', value: formatDate(battery.updatedAt)),
      ]),
    ],
  );
}
