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
          'Assigned intents, launch posture, active windows, and conformance attention.',
      load: load ?? AeroArcApiClient().operations,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _IntentTable(
          intents: data.operationalIntents,
          conformance: data.conformance,
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
  const _IntentTable({required this.intents, required this.conformance});

  final List<OperationalIntent> intents;
  final List<ConformanceSummary> conformance;

  @override
  State<_IntentTable> createState() => _IntentTableState();
}

class _IntentTableState extends State<_IntentTable> {
  _IntentFilter _filter = _IntentFilter.all;

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
              (intent) => (conformanceByIntent[intent.id]?.alertCount ?? 0) > 0,
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
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Intent')),
                          DataColumn(label: Text('Aircraft')),
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
                                  _IntentPostureCell(
                                    intent: intent,
                                    conformance: conformanceByIntent[intent.id],
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
      message:
          '${summary.alertCount} alert${summary.alertCount == 1 ? '' : 's'}',
      child: StatusBadge(label: summary.status),
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
    final linked = summaries
        .where((summary) => summary.alertCount > 0)
        .toList();
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
                      '${summary.intentId} / ${summary.aircraftId} - ${formatPercent(summary.score)} score, ${summary.alertCount} alerts',
                      style: const TextStyle(color: Color(0xFFC4D0EE)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: summary.status),
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
  if ((conformance?.alertCount ?? 0) > 0) return 'warning';
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
  if ((conformance?.alertCount ?? 0) > 0) {
    reasons.add(
      '${conformance!.alertCount} conformance alert${conformance.alertCount == 1 ? '' : 's'} linked.',
    );
  }
  return reasons;
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
          DetailLine(label: 'Status', value: displayEnum(conformance.status)),
          DetailLine(label: 'Alerts', value: '${conformance.alertCount}'),
          DetailLine(label: 'Score', value: formatPercent(conformance.score)),
          DetailLine(
            label: 'Reportability',
            value: displayEnum(conformance.reportabilityStatus),
          ),
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
    status: StatusBadge(label: summary.status),
    children: [
      detailSection('Linked Conformance', [
        DetailLine(label: 'Summary ID', value: summary.id),
        DetailLine(label: 'Intent', value: summary.intentId),
        DetailLine(label: 'Flight', value: summary.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: summary.aircraftId),
        DetailLine(label: 'Score', value: formatPercent(summary.score)),
        DetailLine(label: 'Alerts', value: '${summary.alertCount}'),
        DetailLine(
          label: 'Reportability',
          value: displayEnum(summary.reportabilityStatus),
        ),
        DetailLine(label: 'Updated', value: formatDate(summary.updatedAt)),
      ]),
    ],
  );
}
