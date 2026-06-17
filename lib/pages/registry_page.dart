import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<OperationsDashboard>(
      title: 'Operations',
      subtitle:
          'Operational intents, authorization path, route windows, and conformance requirements.',
      load: AeroArcApiClient().operations,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _IntentTable(intents: data.operationalIntents),
        const SizedBox(height: 18),
        TwoColumn(
          left: _IntentDetailPanel(intents: data.operationalIntents),
          right: _ConformanceLinkPanel(summaries: data.conformance),
        ),
      ],
    );
  }
}

class _IntentTable extends StatelessWidget {
  const _IntentTable({required this.intents});

  final List<OperationalIntent> intents;

  @override
  Widget build(BuildContext context) {
    if (intents.isEmpty) {
      return const EmptyPanel(message: 'No operational intents are available.');
    }
    return Panel(
      title: 'Operational Intent Register',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Intent')),
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Authorization')),
              DataColumn(label: Text('Population')),
              DataColumn(label: Text('Window')),
              DataColumn(label: Text('Altitude')),
              DataColumn(label: Text('Conformance')),
            ],
            rows: [
              for (final intent in intents)
                DataRow(
                  onSelectChanged: (_) => _showIntentDetails(context, intent),
                  cells: [
                    DataCell(
                      Text(
                        intent.name.isEmpty ? intent.id : intent.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(intent.aircraftId)),
                    DataCell(StatusBadge(label: intent.status)),
                    DataCell(Text(displayEnum(intent.authorizationPath))),
                    DataCell(Text(displayEnum(intent.populationCategory))),
                    DataCell(
                      Text(
                        '${formatDate(intent.plannedStartAt)} -> ${formatDate(intent.plannedEndAt)}',
                      ),
                    ),
                    DataCell(
                      Text(
                        formatFeetRange(
                          intent.minAltitudeFtAgl,
                          intent.maxAltitudeFtAgl,
                        ),
                      ),
                    ),
                    DataCell(
                      StatusBadge(
                        label: intent.conformanceRequired
                            ? 'required'
                            : 'not_required',
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

class _IntentDetailPanel extends StatelessWidget {
  const _IntentDetailPanel({required this.intents});

  final List<OperationalIntent> intents;

  @override
  Widget build(BuildContext context) {
    final selected = intents.isEmpty ? null : intents.first;
    return Panel(
      title: 'Next Intent Detail',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected == null
            ? const Text(
                'No intent detail available.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              )
            : Column(
                children: [
                  DetailLine(label: 'Intent', value: selected.id),
                  DetailLine(label: 'Name', value: selected.name),
                  DetailLine(label: 'Summary', value: selected.summary),
                  DetailLine(
                    label: 'Use case',
                    value: selected.useCase ?? 'Not provided',
                  ),
                  DetailLine(
                    label: 'Route',
                    value: selected.routeSummary ?? 'Not provided',
                  ),
                  DetailLine(
                    label: 'Supervisor',
                    value: selected.supervisorId ?? 'Not assigned',
                  ),
                  DetailLine(
                    label: 'Coordinator',
                    value: selected.flightCoordinatorId ?? 'Not assigned',
                  ),
                ],
              ),
      ),
    );
  }
}

class _ConformanceLinkPanel extends StatelessWidget {
  const _ConformanceLinkPanel({required this.summaries});

  final List<ConformanceSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Linked Conformance',
      child: RowList(
        children: [
          for (final summary in summaries.take(8))
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

void _showIntentDetails(BuildContext context, OperationalIntent intent) {
  showDetailsSheet(
    context,
    title: intent.name.isEmpty ? intent.id : intent.name,
    status: StatusBadge(label: intent.status),
    children: [
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
    ],
  );
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
