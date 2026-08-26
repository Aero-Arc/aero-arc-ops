import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';
import 'intent_workflow_page.dart';

class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key, this.load});

  final Future<OperationsDashboard> Function()? load;

  @override
  Widget build(BuildContext context) {
    return DashboardPage<OperationsDashboard>(
      title: 'Operations',
      subtitle:
          'Live aircraft connectivity, telemetry freshness, assigned intents, and conformance attention.',
      load: load ?? AeroArcApiClient().operations,
      autoRefreshInterval: const Duration(seconds: 1),
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _LiveAircraftPanel(states: data.liveAircraft),
        const SizedBox(height: 18),
        _IntentTable(
          intents: data.operationalIntents,
          conformance: data.conformance,
          liveAircraft: data.liveAircraft,
        ),
        const SizedBox(height: 18),
        TwoColumn(
          left: _OperationsAttentionPanel(
            intents: data.operationalIntents,
            conformance: data.conformance,
          ),
          right: _ConformanceLinkPanel(summaries: data.conformance),
        ),
      ],
    );
  }
}

class _LiveAircraftPanel extends StatelessWidget {
  const _LiveAircraftPanel({required this.states});

  final List<AircraftLiveState> states;

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) {
      return const EmptyPanel(
        message:
            'No live aircraft state is available. Aircraft and intent records remain usable while registry or telemetry data is unavailable.',
      );
    }
    final connected = states
        .where((state) => state.connection.status == 'connected')
        .length;
    final staleConnections = states
        .where((state) => state.connection.status == 'stale')
        .length;
    final freshTelemetry = states
        .where((state) => state.telemetry.status == 'fresh')
        .length;
    final missingTelemetry = states
        .where(
          (state) =>
              const {'missing', 'unavailable'}.contains(state.telemetry.status),
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricGrid(
          metrics: [
            DashboardMetric(
              label: 'Connected aircraft',
              value: '$connected/${states.length}',
              status: connected == states.length ? 'ready' : 'warning',
            ),
            DashboardMetric(
              label: 'Stale connections',
              value: '$staleConnections',
              status: staleConnections == 0 ? 'ready' : 'warning',
            ),
            DashboardMetric(
              label: 'Fresh telemetry',
              value: '$freshTelemetry/${states.length}',
              status: freshTelemetry == states.length ? 'ready' : 'warning',
            ),
            DashboardMetric(
              label: 'Missing telemetry',
              value: '$missingTelemetry',
              status: missingTelemetry == 0 ? 'ready' : 'warning',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Live Aircraft',
          child: RowList(
            children: [
              for (final state in states)
                ActionRow(
                  onTap: () => _showLiveAircraftDetails(context, state),
                  child: _LiveAircraftRow(state: state),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveAircraftRow extends StatelessWidget {
  const _LiveAircraftRow({required this.state});

  final AircraftLiveState state;

  @override
  Widget build(BuildContext context) {
    final connection = state.connection;
    final telemetry = state.telemetry;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.aircraftId,
              style: const TextStyle(
                color: Color(0xFFD6E0FF),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (connection.agentId != null) 'Agent ${connection.agentId}',
                if (connection.relayId != null) 'Relay ${connection.relayId}',
                if (connection.agentId == null && connection.relayId == null)
                  'No registry placement',
              ].join(' · '),
              style: const TextStyle(color: Color(0xFF93A3C7)),
            ),
          ],
        );
        final statuses = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StateChip(
              label: 'Connection',
              status: connection.status,
              detail: _ageLabel(connection.lastHeartbeatAt),
            ),
            _StateChip(
              label: 'Position',
              status: telemetry.position?.status ?? 'missing',
              detail: _ageLabel(telemetry.position?.recordedAt),
            ),
            _StateChip(
              label: _batteryLabel(telemetry.battery),
              status: telemetry.battery?.status ?? 'missing',
              detail: _ageLabel(telemetry.battery?.recordedAt),
            ),
            _StateChip(
              label: _vehicleLabel(telemetry.vehicle),
              status: telemetry.vehicle?.status ?? 'missing',
              detail: _ageLabel(telemetry.vehicle?.recordedAt),
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 12), statuses],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: identity),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: statuses),
          ],
        );
      },
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.status,
    required this.detail,
  });

  final String label;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label · ${displayEnum(status)} · $detail',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConnectionCell extends StatelessWidget {
  const _ConnectionCell({required this.state});

  final AircraftLiveState? state;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state == null) {
      return const StatusBadge(label: 'unavailable');
    }
    return Tooltip(
      message:
          '${state.connection.relayId ?? 'No relay'}\nHeartbeat ${_ageLabel(state.connection.lastHeartbeatAt)}',
      child: StatusBadge(label: state.connection.status),
    );
  }
}

class _TelemetryGroupCell extends StatelessWidget {
  const _TelemetryGroupCell({required this.label, required this.group});

  final String label;
  final TelemetryGroup? group;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    if (group == null) {
      return const Text('Missing', style: TextStyle(color: Color(0xFF7F90B6)));
    }
    return Tooltip(
      message: '$label recorded ${formatDate(group.recordedAt)}',
      child: Text(
        '${displayEnum(group.status)} · ${_ageLabel(group.recordedAt)}',
        style: TextStyle(
          color: statusColor(group.status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BatteryCell extends StatelessWidget {
  const _BatteryCell({required this.state});

  final AircraftLiveState? state;

  @override
  Widget build(BuildContext context) {
    final battery = state?.telemetry.battery;
    if (battery == null) {
      return _TelemetryGroupCell(label: 'Battery', group: null);
    }
    return Tooltip(
      message:
          '${displayEnum(battery.status)} battery recorded ${formatDate(battery.recordedAt)}',
      child: Text(
        '${_batteryLabel(battery)} · ${displayEnum(battery.status)} · ${_ageLabel(battery.recordedAt)}',
        style: TextStyle(
          color: statusColor(battery.status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _batteryLabel(BatteryTelemetry? battery) {
  final remaining = battery?.remainingPct;
  return remaining == null
      ? 'Battery'
      : 'Battery ${remaining.toStringAsFixed(0)}%';
}

String _vehicleLabel(VehicleTelemetry? vehicle) {
  if (vehicle == null) return 'Vehicle';
  return switch (vehicle.armed) {
    true => 'Armed',
    false => 'Disarmed',
    null => 'Vehicle',
  };
}

String _ageLabel(DateTime? timestamp, {DateTime? now}) {
  if (timestamp == null) return 'No sample';
  final age = (now ?? DateTime.now()).toUtc().difference(timestamp.toUtc());
  if (age.isNegative || age.inSeconds < 1) return 'now';
  if (age.inSeconds < 60) return '${age.inSeconds}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 48) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

void _showLiveAircraftDetails(BuildContext context, AircraftLiveState state) {
  final connection = state.connection;
  final telemetry = state.telemetry;
  showDetailsSheet(
    context,
    title: '${state.aircraftId} live state',
    status: StatusBadge(label: connection.status),
    children: [
      detailSection('Connection', [
        DetailLine(label: 'Status', value: displayEnum(connection.status)),
        DetailLine(label: 'Agent', value: connection.agentId ?? 'Unmapped'),
        DetailLine(label: 'Relay', value: connection.relayId ?? 'Unplaced'),
        DetailLine(
          label: 'Heartbeat',
          value:
              '${formatDate(connection.lastHeartbeatAt)} (${_ageLabel(connection.lastHeartbeatAt)})',
        ),
        DetailLine(
          label: 'Placement updated',
          value: formatDate(connection.placementLastUpdatedAt),
        ),
      ]),
      detailSection('Telemetry Availability', [
        DetailLine(label: 'Overall', value: displayEnum(telemetry.status)),
        DetailLine(
          label: 'Last observed',
          value:
              '${formatDate(telemetry.lastObservedAt)} (${_ageLabel(telemetry.lastObservedAt)})',
        ),
      ]),
      _telemetryGroupDetails('Position', telemetry.position, [
        DetailLine(
          label: 'Coordinates',
          value: telemetry.position == null
              ? 'Not available'
              : '${telemetry.position!.latitudeDeg.toStringAsFixed(5)}, ${telemetry.position!.longitudeDeg.toStringAsFixed(5)}',
        ),
        DetailLine(
          label: 'Relative altitude',
          value: formatMeters(telemetry.position?.relativeAltitudeM),
        ),
        DetailLine(
          label: 'Groundspeed',
          value: _metersPerSecond(telemetry.position?.groundspeedMps),
        ),
        DetailLine(
          label: 'Heading',
          value: _degrees(telemetry.position?.headingDeg),
        ),
      ]),
      _telemetryGroupDetails('Battery', telemetry.battery, [
        DetailLine(
          label: 'Remaining',
          value: formatPercentagePoints(telemetry.battery?.remainingPct),
        ),
        DetailLine(
          label: 'Voltage',
          value: _unit(telemetry.battery?.voltageV, 'V'),
        ),
        DetailLine(
          label: 'Current',
          value: _unit(telemetry.battery?.currentA, 'A'),
        ),
        DetailLine(
          label: 'Temperature',
          value: _unit(telemetry.battery?.temperatureC, '°C'),
        ),
      ]),
      _telemetryGroupDetails('Vehicle', telemetry.vehicle, [
        DetailLine(
          label: 'Armed',
          value: telemetry.vehicle?.armed == null
              ? 'Not available'
              : yesNo(telemetry.vehicle!.armed!),
        ),
        DetailLine(
          label: 'System status',
          value: telemetry.vehicle?.systemStatus == null
              ? 'Not available'
              : displayEnum(telemetry.vehicle!.systemStatus!),
        ),
        DetailLine(
          label: 'Custom mode',
          value: telemetry.vehicle?.customMode?.toString() ?? 'Not available',
        ),
      ]),
      _telemetryGroupDetails('System', telemetry.system, [
        DetailLine(
          label: 'Mainloop load',
          value: formatPercentagePoints(telemetry.system?.mainloopLoadPct),
        ),
        DetailLine(
          label: 'Communication drop rate',
          value: formatPercentagePoints(
            telemetry.system?.communicationDropRatePct,
          ),
        ),
        DetailLine(
          label: 'Communication errors',
          value:
              telemetry.system?.communicationErrorCount?.toString() ??
              'Not available',
        ),
      ]),
      _telemetryGroupDetails('HUD', telemetry.hud, [
        DetailLine(
          label: 'Groundspeed',
          value: _metersPerSecond(telemetry.hud?.groundspeedMps),
        ),
        DetailLine(
          label: 'Airspeed',
          value: _metersPerSecond(telemetry.hud?.airspeedMps),
        ),
        DetailLine(
          label: 'Climb rate',
          value: _metersPerSecond(telemetry.hud?.climbRateMps),
        ),
      ]),
      _telemetryGroupDetails('Extended State', telemetry.extendedState, [
        DetailLine(
          label: 'VTOL state',
          value: telemetry.extendedState?.vtolState == null
              ? 'Not available'
              : displayEnum(telemetry.extendedState!.vtolState!),
        ),
        DetailLine(
          label: 'Landed state',
          value: telemetry.extendedState?.landedState == null
              ? 'Not available'
              : displayEnum(telemetry.extendedState!.landedState!),
        ),
      ]),
      _telemetryGroupDetails('GPS', telemetry.gps, [
        DetailLine(
          label: 'Fix type',
          value: telemetry.gps?.fixType == null
              ? 'Not available'
              : displayEnum(telemetry.gps!.fixType!),
        ),
        DetailLine(
          label: 'Satellites',
          value:
              telemetry.gps?.satellitesVisible?.toString() ?? 'Not available',
        ),
        DetailLine(
          label: 'Horizontal accuracy',
          value: formatMeters(telemetry.gps?.horizontalAccuracyM),
        ),
      ]),
    ],
  );
}

Widget _telemetryGroupDetails(
  String title,
  TelemetryGroup? group,
  List<Widget> details,
) {
  return detailSection(title, [
    DetailLine(
      label: 'Sample status',
      value: group == null ? 'Missing' : displayEnum(group.status),
    ),
    DetailLine(
      label: 'Recorded',
      value: group == null
          ? 'No sample'
          : '${formatDate(group.recordedAt)} (${_ageLabel(group.recordedAt)})',
    ),
    ...details,
  ]);
}

String _unit(double? value, String unit) =>
    value == null ? 'Not available' : '${value.toStringAsFixed(1)} $unit';

String _metersPerSecond(double? value) => _unit(value, 'm/s');

String _degrees(double? value) => _unit(value, '°');

enum _IntentFilter {
  all('All'),
  needsAttention('Needs attention'),
  active('Active'),
  readyToActivate('Ready to activate'),
  draft('Draft'),
  conformanceAlerts('Conformance alerts');

  const _IntentFilter(this.label);

  final String label;
}

class _IntentTable extends StatefulWidget {
  const _IntentTable({
    required this.intents,
    required this.conformance,
    required this.liveAircraft,
  });

  final List<OperationalIntent> intents;
  final List<ConformanceSummary> conformance;
  final List<AircraftLiveState> liveAircraft;

  @override
  State<_IntentTable> createState() => _IntentTableState();
}

class _IntentTableState extends State<_IntentTable> {
  _IntentFilter _filter = _IntentFilter.all;
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  Map<String, ConformanceSummary> get _conformanceByIntent => {
    for (final summary in widget.conformance) summary.intentId: summary,
  };

  List<OperationalIntent> get _filteredIntents {
    final conformanceByIntent = _conformanceByIntent;
    return switch (_filter) {
      _IntentFilter.all => widget.intents,
      _IntentFilter.needsAttention =>
        widget.intents
            .where(
              (intent) =>
                  _intentNeedsAttention(intent, conformanceByIntent[intent.id]),
            )
            .toList(),
      _IntentFilter.active =>
        widget.intents.where((intent) => intent.status == 'active').toList(),
      _IntentFilter.readyToActivate =>
        widget.intents.where((intent) => intent.status == 'accepted').toList(),
      _IntentFilter.draft =>
        widget.intents.where((intent) => intent.status == 'draft').toList(),
      _IntentFilter.conformanceAlerts =>
        widget.intents
            .where(
              (intent) => switch (conformanceByIntent[intent.id]) {
                final summary? => _conformanceNeedsAttention(summary),
                null => false,
              },
            )
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.intents.isEmpty) {
      return const EmptyPanel(message: 'No operational intents are available.');
    }
    final intents = _filteredIntents;
    final conformanceByIntent = _conformanceByIntent;
    final liveByAircraft = {
      for (final state in widget.liveAircraft) state.aircraftId: state,
    };
    return Panel(
      title: 'Intent Register',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IntentFilters(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 12),
            if (intents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No intents match this filter.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          columns: const [
                            DataColumn(label: Text('Intent')),
                            DataColumn(label: Text('Aircraft')),
                            DataColumn(label: Text('Connection')),
                            DataColumn(label: Text('Position')),
                            DataColumn(label: Text('Battery')),
                            DataColumn(label: Text('Posture')),
                            DataColumn(label: Text('Window')),
                            DataColumn(label: Text('Conformance')),
                            DataColumn(label: Text('Open')),
                          ],
                          rows: [
                            for (final intent in intents)
                              DataRow(
                                cells: [
                                  DataCell(_IntentAction(intent: intent)),
                                  DataCell(
                                    _AircraftAction(
                                      aircraftId: intent.aircraftId,
                                    ),
                                  ),
                                  DataCell(
                                    _ConnectionCell(
                                      state: liveByAircraft[intent.aircraftId],
                                    ),
                                  ),
                                  DataCell(
                                    _TelemetryGroupCell(
                                      label: 'Position',
                                      group: liveByAircraft[intent.aircraftId]
                                          ?.telemetry
                                          .position,
                                    ),
                                  ),
                                  DataCell(
                                    _BatteryCell(
                                      state: liveByAircraft[intent.aircraftId],
                                    ),
                                  ),
                                  DataCell(
                                    _IntentPostureCell(
                                      intent: intent,
                                      conformance:
                                          conformanceByIntent[intent.id],
                                      onPressed: () => _showIntentDetails(
                                        context,
                                        intent,
                                        conformanceByIntent[intent.id],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${formatDate(intent.plannedStartAt)} -> ${formatDate(intent.plannedEndAt)}',
                                    ),
                                  ),
                                  DataCell(
                                    _ConformanceCell(
                                      summary: conformanceByIntent[intent.id],
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Open intent workflow',
                                      onPressed: () =>
                                          _openIntentWorkflow(context, intent),
                                      icon: const Icon(Icons.open_in_new),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
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

class _IntentFilters extends StatelessWidget {
  const _IntentFilters({required this.selected, required this.onSelected});

  final _IntentFilter selected;
  final ValueChanged<_IntentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _IntentFilter.values)
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

class _IntentAction extends StatelessWidget {
  const _IntentAction({required this.intent});

  final OperationalIntent intent;

  @override
  Widget build(BuildContext context) {
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

class _AircraftAction extends StatelessWidget {
  const _AircraftAction({required this.aircraftId});

  final String aircraftId;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _openAircraftMap(context, aircraftId),
      icon: const Icon(Icons.map_outlined, size: 16),
      label: Text(aircraftId),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF91A0FF),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _IntentPostureCell extends StatelessWidget {
  const _IntentPostureCell({
    required this.intent,
    required this.conformance,
    required this.onPressed,
  });

  final OperationalIntent intent;
  final ConformanceSummary? conformance;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final posture = _intentPosture(intent, conformance);
    final detail = _intentAttentionReasons(intent, conformance).isEmpty
        ? 'No operation blockers surfaced'
        : _intentAttentionReasons(
            intent,
            conformance,
          ).map((reason) => '- $reason').join('\n');
    return Tooltip(
      message: '${displayEnum(posture)}\n$detail',
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: StatusBadge(label: posture),
      ),
    );
  }
}

class _ConformanceCell extends StatelessWidget {
  const _ConformanceCell({required this.summary});

  final ConformanceSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) {
      return const Text(
        'Not linked',
        style: TextStyle(color: Color(0xFF7F90B6)),
      );
    }
    return Tooltip(
      message: summary.isLiveProjection
          ? '${displayEnum(summary.monitoringStatus ?? 'unknown')} monitoring · ${displayEnum(summary.recordingStatus ?? 'unknown')} recording · ${summary.activeViolationCount} active findings'
          : '${summary.alertCount} alert${summary.alertCount == 1 ? '' : 's'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusBadge(label: _operationConformanceCondition(summary)),
          if (summary.isLiveProjection) ...[
            const SizedBox(height: 4),
            Text(
              '${displayEnum(summary.monitoringStatus ?? 'unknown')} · ${displayEnum(summary.recordingStatus ?? 'unknown')}',
              style: const TextStyle(color: Color(0xFF93A3C7), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationsAttentionPanel extends StatelessWidget {
  const _OperationsAttentionPanel({
    required this.intents,
    required this.conformance,
  });

  final List<OperationalIntent> intents;
  final List<ConformanceSummary> conformance;

  @override
  Widget build(BuildContext context) {
    final conformanceByIntent = {
      for (final summary in conformance) summary.intentId: summary,
    };
    final items = intents
        .where(
          (intent) =>
              _intentNeedsAttention(intent, conformanceByIntent[intent.id]),
        )
        .take(8)
        .toList();
    return Panel(
      title: 'Needs Attention',
      child: RowList(
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No operational intents need attention.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              ),
            ),
          for (final intent in items)
            ActionRow(
              onTap: () => _showIntentDetails(
                context,
                intent,
                conformanceByIntent[intent.id],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${intent.name.isEmpty ? intent.id : intent.name}: ${_topIntentAttentionReason(intent, conformanceByIntent[intent.id])}',
                      style: const TextStyle(
                        color: Color(0xFFC4D0EE),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(
                    label: _intentPosture(
                      intent,
                      conformanceByIntent[intent.id],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConformanceLinkPanel extends StatelessWidget {
  const _ConformanceLinkPanel({required this.summaries});

  final List<ConformanceSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final linked = summaries.where(_conformanceNeedsAttention).toList();
    return Panel(
      title: 'Conformance Attention',
      child: RowList(
        children: [
          if (linked.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No conformance alerts are linked.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              ),
            ),
          for (final summary in linked.take(8))
            ActionRow(
              onTap: () => _showConformanceSummaryDetails(context, summary),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.isLiveProjection
                          ? '${summary.intentId} / ${summary.aircraftId} · ${displayEnum(summary.monitoringStatus ?? 'unknown')} monitoring · ${summary.activeViolationCount} active findings'
                          : '${summary.intentId} / ${summary.aircraftId} · ${formatPercent(summary.score)} score, ${summary.alertCount} alerts',
                      style: const TextStyle(color: Color(0xFFC4D0EE)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: _operationConformanceCondition(summary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

bool _intentNeedsAttention(
  OperationalIntent intent,
  ConformanceSummary? conformance,
) {
  return _intentAttentionReasons(intent, conformance).isNotEmpty;
}

String _intentPosture(
  OperationalIntent intent,
  ConformanceSummary? conformance,
) {
  if (_intentIsOverdue(intent)) {
    return 'overdue';
  }
  if (conformance != null && _conformanceNeedsAttention(conformance)) {
    return _conformanceAttentionStatus(conformance);
  }
  return switch (intent.status) {
    'active' => 'active',
    'accepted' => 'ready',
    'draft' || 'submitted' => 'warning',
    'rejected' || 'cancelled' || 'expired' => 'blocked',
    _ => intent.status,
  };
}

List<String> _intentAttentionReasons(
  OperationalIntent intent,
  ConformanceSummary? conformance,
) {
  final reasons = <String>[];
  if (intent.status == 'draft') {
    reasons.add('Draft intent has not been submitted.');
  } else if (intent.status == 'submitted') {
    reasons.add('Submitted intent is waiting for acceptance.');
  } else if (intent.status == 'accepted') {
    reasons.add('Accepted intent is not active yet.');
  } else if (intent.status == 'rejected') {
    reasons.add('Intent was rejected.');
  }
  if (_intentIsOverdue(intent)) {
    reasons.add(
      'Active flight is beyond its planned end (${_ageLabel(intent.plannedEndAt)}); monitoring must continue until explicit completion.',
    );
  }
  if (conformance != null && _conformanceNeedsAttention(conformance)) {
    reasons.add(
      conformance.isLiveProjection
          ? '${displayEnum(_operationConformanceCondition(conformance))} condition, ${displayEnum(conformance.monitoringStatus ?? 'unknown')} monitoring, and ${conformance.activeViolationCount} active findings.'
          : '${conformance.alertCount} conformance alert${conformance.alertCount == 1 ? '' : 's'} linked.',
    );
  }
  return reasons;
}

bool _intentIsOverdue(OperationalIntent intent, {DateTime? now}) {
  final plannedEndAt = intent.plannedEndAt;
  if (intent.status != 'active' || plannedEndAt == null) return false;
  return !(now ?? DateTime.now()).toUtc().isBefore(plannedEndAt.toUtc());
}

String _operationConformanceCondition(ConformanceSummary summary) {
  final condition = summary.condition;
  return condition == null || condition.isEmpty ? summary.status : condition;
}

bool _conformanceNeedsAttention(ConformanceSummary summary) {
  if (!summary.isLiveProjection) return summary.alertCount > 0;
  return _operationConformanceCondition(summary) != 'conforming' ||
      summary.monitoringStatus != 'current' ||
      summary.recordingStatus != 'confirmed' ||
      summary.activeViolationCount > 0;
}

String _conformanceAttentionStatus(ConformanceSummary summary) {
  if (!summary.isLiveProjection) return 'warning';
  final condition = _operationConformanceCondition(summary);
  if (condition != 'conforming') return condition;
  if (summary.monitoringStatus != 'current') {
    return summary.monitoringStatus ?? 'unavailable';
  }
  if (summary.recordingStatus != 'confirmed') {
    return summary.recordingStatus ?? 'unavailable';
  }
  return summary.activeViolationCount > 0 ? 'warning' : 'ready';
}

String _topIntentAttentionReason(
  OperationalIntent intent,
  ConformanceSummary? conformance,
) {
  final reasons = _intentAttentionReasons(intent, conformance);
  if (reasons.isNotEmpty) return reasons.first;
  return 'Review operational posture';
}

void _showIntentDetails(
  BuildContext context,
  OperationalIntent intent,
  ConformanceSummary? conformance,
) {
  final reasons = _intentAttentionReasons(intent, conformance);
  showDetailsSheet(
    context,
    title: intent.name.isEmpty ? intent.id : intent.name,
    status: StatusBadge(label: _intentPosture(intent, conformance)),
    children: [
      detailSection('Operational Posture', [
        DetailLine(
          label: 'Posture',
          value: displayEnum(_intentPosture(intent, conformance)),
        ),
        DetailLine(
          label: 'Needs attention',
          value: reasons.isEmpty
              ? 'No operation blockers surfaced'
              : reasons.join('\n'),
        ),
        DetailLine(
          label: 'Workflow',
          value:
              'Open the intent workflow to create, modify, check, or activate this intent.',
        ),
      ]),
      detailSection('Intent State', [
        DetailLine(label: 'Intent ID', value: intent.id),
        DetailLine(label: 'Version', value: '${intent.version}'),
        DetailLine(label: 'Aircraft', value: intent.aircraftId),
        DetailLine(label: 'Status', value: displayEnum(intent.status)),
        DetailLine(label: 'Updated', value: formatDate(intent.updatedAt)),
      ]),
      detailSection('Authorization And Constraints', [
        DetailLine(
          label: 'Authorization',
          value: displayEnum(intent.authorizationPath),
        ),
        DetailLine(
          label: 'Authorization ID',
          value: intent.authorizationId ?? 'Not linked',
        ),
        DetailLine(
          label: 'Population',
          value: displayEnum(intent.populationCategory),
        ),
        DetailLine(
          label: 'Area',
          value: intent.operatingAreaId ?? 'Not provided',
        ),
        DetailLine(
          label: 'Altitude',
          value: formatFeetRange(
            intent.minAltitudeFtAgl,
            intent.maxAltitudeFtAgl,
          ),
        ),
        DetailLine(
          label: 'Conformance required',
          value: yesNo(intent.conformanceRequired),
        ),
      ]),
      detailSection('Operational Detail', [
        DetailLine(label: 'Summary', value: intent.summary),
        DetailLine(label: 'Use case', value: intent.useCase ?? 'Not provided'),
        DetailLine(
          label: 'Route',
          value: intent.routeSummary ?? 'Not provided',
        ),
        DetailLine(
          label: 'Window',
          value:
              '${formatDate(intent.plannedStartAt)} -> ${formatDate(intent.plannedEndAt)}',
        ),
        DetailLine(
          label: 'Supervisor',
          value: intent.supervisorId ?? 'Not assigned',
        ),
        DetailLine(
          label: 'Coordinator',
          value: intent.flightCoordinatorId ?? 'Not assigned',
        ),
      ]),
      if (conformance != null)
        detailSection('Linked Conformance', [
          DetailLine(
            label: 'Condition',
            value: displayEnum(_operationConformanceCondition(conformance)),
          ),
          if (conformance.isLiveProjection) ...[
            DetailLine(
              label: 'Monitoring',
              value: displayEnum(conformance.monitoringStatus ?? 'unknown'),
            ),
            DetailLine(
              label: 'Recording',
              value: displayEnum(conformance.recordingStatus ?? 'unknown'),
            ),
            DetailLine(
              label: 'Observed',
              value: formatDate(conformance.observedAt),
            ),
          ] else ...[
            DetailLine(label: 'Alerts', value: '${conformance.alertCount}'),
            DetailLine(label: 'Score', value: formatPercent(conformance.score)),
            DetailLine(
              label: 'Reportability',
              value: displayEnum(conformance.reportabilityStatus),
            ),
          ],
        ]),
    ],
  );
}

void _openIntentWorkflow(BuildContext context, OperationalIntent intent) {
  Navigator.of(context).pushNamed(
    '/aircraft/${intent.aircraftId}/intent/new',
    arguments: IntentWorkflowRouteArguments(initialIntent: intent),
  );
}

void _openAircraftMap(BuildContext context, String aircraftId) {
  Navigator.of(context).pushNamed('/aircraft/$aircraftId/map');
}

void _showConformanceSummaryDetails(
  BuildContext context,
  ConformanceSummary summary,
) {
  showDetailsSheet(
    context,
    title: summary.intentId,
    status: StatusBadge(label: _operationConformanceCondition(summary)),
    children: [
      detailSection('Linked Conformance', [
        DetailLine(label: 'Summary ID', value: summary.id),
        DetailLine(label: 'Intent', value: summary.intentId),
        DetailLine(label: 'Flight', value: summary.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: summary.aircraftId),
        DetailLine(
          label: 'Condition',
          value: displayEnum(_operationConformanceCondition(summary)),
        ),
        if (summary.isLiveProjection) ...[
          DetailLine(
            label: 'Monitoring',
            value: displayEnum(summary.monitoringStatus ?? 'unknown'),
          ),
          DetailLine(
            label: 'Recording',
            value: displayEnum(summary.recordingStatus ?? 'unknown'),
          ),
          DetailLine(label: 'Observed', value: formatDate(summary.observedAt)),
          DetailLine(
            label: 'Assignment generation',
            value: '${summary.assignmentGeneration ?? 0}',
          ),
          DetailLine(
            label: 'Evaluation revision',
            value: '${summary.evaluationRevision ?? 0}',
          ),
          DetailLine(
            label: 'Frame ID',
            value: summary.frameId ?? 'Not provided',
          ),
        ] else ...[
          DetailLine(label: 'Score', value: formatPercent(summary.score)),
          DetailLine(label: 'Alerts', value: '${summary.alertCount}'),
          DetailLine(
            label: 'Reportability',
            value: displayEnum(summary.reportabilityStatus),
          ),
          DetailLine(label: 'Updated', value: formatDate(summary.updatedAt)),
        ],
      ]),
    ],
  );
}
