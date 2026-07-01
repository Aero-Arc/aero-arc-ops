import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';
import 'intent_workflow_page.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key, this.load});

  final Future<AircraftListResponse> Function()? load;

  @override
  Widget build(BuildContext context) {
    return DashboardPage<AircraftListResponse>(
      title: 'Aircraft',
      subtitle:
          'Fleet identity, assigned intent, live state, telemetry, maintenance, and readiness.',
      load: load ?? AeroArcApiClient().aircraft,
      builder: (context, data) => [
        _FleetMetrics(aircraft: data.aircraft),
        const SizedBox(height: 18),
        _AircraftTable(aircraft: data.aircraft),
        const SizedBox(height: 18),
        _NeedsAttentionPanel(aircraft: data.aircraft),
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

enum _FleetFilter {
  all('All'),
  needsAttention('Needs attention'),
  ready('Ready'),
  live('Live'),
  hasIntent('Has intent'),
  noIntent('No intent');

  const _FleetFilter(this.label);

  final String label;
}

class _AircraftTable extends StatefulWidget {
  const _AircraftTable({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  State<_AircraftTable> createState() => _AircraftTableState();
}

class _AircraftTableState extends State<_AircraftTable> {
  _FleetFilter _filter = _FleetFilter.all;

  List<AircraftDashboard> get _filteredAircraft {
    return switch (_filter) {
      _FleetFilter.all => widget.aircraft,
      _FleetFilter.needsAttention =>
        widget.aircraft.where((item) => _needsAttention(item)).toList(),
      _FleetFilter.ready =>
        widget.aircraft
            .where((item) => item.readiness.status == 'ready')
            .toList(),
      _FleetFilter.live =>
        widget.aircraft.where((item) => item.liveStateAvailable).toList(),
      _FleetFilter.hasIntent =>
        widget.aircraft.where((item) => item.currentIntent != null).toList(),
      _FleetFilter.noIntent =>
        widget.aircraft.where((item) => item.currentIntent == null).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.aircraft.isEmpty) {
      return const EmptyPanel(message: 'No aircraft have been registered yet.');
    }
    final aircraft = _filteredAircraft;
    return Panel(
      title: 'Fleet Registry',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FleetFilters(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 12),
            if (aircraft.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No aircraft match this filter.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
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
                          DataColumn(label: Text('Intent')),
                          DataColumn(label: Text('Readiness')),
                          DataColumn(label: Text('Remote ID')),
                          DataColumn(label: Text('Battery')),
                          DataColumn(label: Text('Relay')),
                          DataColumn(label: Text('Last Seen')),
                          DataColumn(label: Text('Map')),
                        ],
                        rows: [
                          for (final item in aircraft)
                            DataRow(
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
                                  _IntentCell(intent: item.currentIntent),
                                ),
                                DataCell(
                                  _ReadinessCell(
                                    item: item,
                                    onPressed: () =>
                                        _showReadinessDetails(context, item),
                                  ),
                                ),
                                DataCell(
                                  StatusBadge(
                                    label: item.aircraft.remoteIdStatus,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatPercent(
                                      item.activeBattery?.stateOfHealth,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.liveState?.relayId ??
                                        'No relay placement',
                                  ),
                                ),
                                DataCell(_LastSeenBadge(item: item)),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Open aircraft map',
                                    onPressed: () =>
                                        _openAircraftMap(context, item),
                                    icon: const Icon(Icons.map_outlined),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FleetFilters extends StatelessWidget {
  const _FleetFilters({required this.selected, required this.onSelected});

  final _FleetFilter selected;
  final ValueChanged<_FleetFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _FleetFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: selected == filter,
            onSelected: (_) => onSelected(filter),
            labelStyle: TextStyle(
              color: selected == filter
                  ? const Color(0xFFE8ECFF)
                  : const Color(0xFF94A2C3),
              fontWeight: selected == filter
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
            selectedColor: const Color(0xFF172A5E),
            backgroundColor: const Color(0xFF081734),
            side: BorderSide(
              color: selected == filter
                  ? const Color(0xFF5A6BFF)
                  : const Color(0xFF12254F),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class _IntentCell extends StatelessWidget {
  const _IntentCell({required this.intent});

  final OperationalIntent? intent;

  @override
  Widget build(BuildContext context) {
    final intent = this.intent;
    if (intent == null) {
      return const Text('None', style: TextStyle(color: Color(0xFF7F90B6)));
    }

    final label =
        '${intent.name.isEmpty ? intent.id : intent.name} v${intent.version}';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: TextButton.icon(
        onPressed: () => _openIntentWorkflow(context, intent),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF91A0FF),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

class _ReadinessCell extends StatelessWidget {
  const _ReadinessCell({required this.item, required this.onPressed});

  final AircraftDashboard item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final readiness = item.readiness;
    final detail = readiness.reasons.isEmpty
        ? 'No readiness blockers'
        : readiness.reasons.map((reason) => '- $reason').join('\n');
    return Tooltip(
      message: '${displayEnum(readiness.status)}\n$detail',
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: StatusBadge(label: readiness.status),
      ),
    );
  }
}

class _NeedsAttentionPanel extends StatelessWidget {
  const _NeedsAttentionPanel({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    final items = aircraft.where(_needsAttention).take(8).toList();
    return Panel(
      title: 'Needs Attention',
      child: RowList(
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No aircraft need attention.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              ),
            ),
          for (final item in items)
            ActionRow(
              onTap: () => _showReadinessDetails(context, item),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${item.aircraft.displayName}: ${_topAttentionReason(item)}',
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

bool _needsAttention(AircraftDashboard item) {
  return item.readiness.status != 'ready' || !item.liveStateAvailable;
}

String _topAttentionReason(AircraftDashboard item) {
  if (item.readiness.reasons.isNotEmpty) return item.readiness.reasons.first;
  if (!item.liveStateAvailable) return 'Live state unavailable';
  return 'Review aircraft readiness';
}

Map<String, List<String>> _groupReadinessReasons(AircraftDashboard item) {
  final groups = <String, List<String>>{};
  final reasons = item.readiness.reasons.isEmpty
      ? const ['No readiness blockers']
      : item.readiness.reasons;
  for (final reason in reasons) {
    final key = _readinessReasonGroup(reason);
    groups.putIfAbsent(key, () => []).add(reason);
  }
  if (!item.liveStateAvailable) {
    groups.putIfAbsent('Telemetry', () => []).add('Live state unavailable');
  }
  return groups;
}

String _readinessReasonGroup(String reason) {
  final lower = reason.toLowerCase();
  if (lower.contains('remote id')) return 'Remote ID';
  if (lower.contains('maintenance')) return 'Maintenance';
  if (lower.contains('battery')) return 'Battery';
  if (lower.contains('telemetry') || lower.contains('live state')) {
    return 'Telemetry';
  }
  if (lower.contains('intent')) return 'Intent';
  if (lower.contains('preflight')) return 'Preflight';
  return 'Readiness';
}

void _showReadinessDetails(BuildContext context, AircraftDashboard item) {
  final groups = _groupReadinessReasons(item);
  showDetailsSheet(
    context,
    title: '${item.aircraft.displayName} readiness',
    status: StatusBadge(label: item.readiness.status),
    children: [
      detailSection('Dispatch Posture', [
        DetailLine(
          label: 'Readiness',
          value: displayEnum(item.readiness.status),
        ),
        DetailLine(
          label: 'Live state',
          value: item.liveStateAvailable ? 'Available' : 'Unavailable',
        ),
        DetailLine(
          label: 'Assigned intent',
          value: item.currentIntent == null
              ? 'None'
              : '${item.currentIntent!.name.isEmpty ? item.currentIntent!.id : item.currentIntent!.name} v${item.currentIntent!.version}',
        ),
      ]),
      detailSection('Checks', [
        for (final entry in groups.entries)
          DetailLine(label: entry.key, value: entry.value.join('\n')),
      ]),
    ],
  );
}

void _openAircraftMap(BuildContext context, AircraftDashboard item) {
  Navigator.of(context).pushNamed('/aircraft/${item.aircraft.id}/map');
}

void _openIntentWorkflow(BuildContext context, OperationalIntent intent) {
  Navigator.of(context).pushNamed(
    '/aircraft/${intent.aircraftId}/intent/new',
    arguments: IntentWorkflowRouteArguments(initialIntent: intent),
  );
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
