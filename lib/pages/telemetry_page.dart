import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class TelemetryPage extends StatelessWidget {
  const TelemetryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<ConformanceDashboard>(
      title: 'Conformance',
      subtitle:
          'Intent-aware conformance summaries, deviations, alert history, and reportability status.',
      load: AeroArcApiClient().conformance,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        TwoColumn(
          left: _SummaryPanel(summaries: data.summaries),
          right: _EventTimeline(events: data.events),
        ),
        const SizedBox(height: 18),
        _ConformanceTable(summaries: data.summaries),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summaries});

  final List<ConformanceSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Conformance Summaries',
      child: RowList(
        children: [
          for (final summary in summaries.take(8))
            ActionRow(
              onTap: () => _showConformanceSummaryDetails(context, summary),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.intentId,
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.aircraftId} - ${formatPercent(summary.score)} - ${summary.alertCount} alerts',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                      ],
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

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.events});

  final List<ConformanceEvent> events;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Deviation Timeline',
      child: RowList(
        children: [
          for (final event in events.take(10))
            ActionRow(
              onTap: () => _showConformanceEventDetails(context, event),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      formatDate(event.occurredAt),
                      style: const TextStyle(
                        color: Color(0xFF8293BB),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayEnum(event.eventCode),
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.message,
                          style: const TextStyle(
                            color: Color(0xFFC4D0EE),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Deviation ${formatMeters(event.deviationMeters)} / ${event.deviationSeconds?.toStringAsFixed(1) ?? '0'} sec',
                          style: const TextStyle(
                            color: Color(0xFF93A3C7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: event.severity),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConformanceTable extends StatelessWidget {
  const _ConformanceTable({required this.summaries});

  final List<ConformanceSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const EmptyPanel(
        message: 'No conformance summaries are available.',
      );
    }
    return Panel(
      title: 'Conformance Records',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Intent')),
              DataColumn(label: Text('Flight')),
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Score')),
              DataColumn(label: Text('Alerts')),
              DataColumn(label: Text('Reportability')),
              DataColumn(label: Text('Updated')),
            ],
            rows: [
              for (final summary in summaries)
                DataRow(
                  onSelectChanged: (_) =>
                      _showConformanceSummaryDetails(context, summary),
                  cells: [
                    DataCell(Text(summary.intentId)),
                    DataCell(Text(summary.flightId ?? 'Not provided')),
                    DataCell(Text(summary.aircraftId)),
                    DataCell(StatusBadge(label: summary.status)),
                    DataCell(Text(formatPercent(summary.score))),
                    DataCell(Text('${summary.alertCount}')),
                    DataCell(StatusBadge(label: summary.reportabilityStatus)),
                    DataCell(Text(formatDate(summary.updatedAt))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
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
      detailSection('Conformance Summary', [
        DetailLine(label: 'Summary ID', value: summary.id),
        DetailLine(label: 'Status', value: displayEnum(summary.status)),
        DetailLine(label: 'Score', value: formatPercent(summary.score)),
        DetailLine(label: 'Alert count', value: '${summary.alertCount}'),
        DetailLine(
          label: 'Reportability',
          value: displayEnum(summary.reportabilityStatus),
        ),
        DetailLine(label: 'Updated', value: formatDate(summary.updatedAt)),
      ]),
      detailSection('Links', [
        DetailLine(
          label: 'Intent',
          value: '${summary.intentId} v${summary.intentVersion}',
        ),
        DetailLine(label: 'Flight', value: summary.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: summary.aircraftId),
      ]),
    ],
  );
}

void _showConformanceEventDetails(
  BuildContext context,
  ConformanceEvent event,
) {
  showDetailsSheet(
    context,
    title: displayEnum(event.eventCode),
    status: StatusBadge(label: event.severity),
    children: [
      detailSection('Deviation', [
        DetailLine(label: 'Event ID', value: event.id),
        DetailLine(label: 'Severity', value: displayEnum(event.severity)),
        DetailLine(label: 'Message', value: event.message),
        DetailLine(label: 'Occurred', value: formatDate(event.occurredAt)),
        DetailLine(
          label: 'Deviation distance',
          value: formatMeters(event.deviationMeters),
        ),
        DetailLine(
          label: 'Deviation seconds',
          value: event.deviationSeconds == null
              ? 'Not provided'
              : '${event.deviationSeconds!.toStringAsFixed(1)} sec',
        ),
        DetailLine(
          label: 'Observed / threshold',
          value:
              '${event.observedValue?.toStringAsFixed(1) ?? 'n/a'} / ${event.thresholdValue?.toStringAsFixed(1) ?? 'n/a'}',
        ),
      ]),
      detailSection('Location And Links', [
        DetailLine(label: 'Intent', value: event.intentId ?? 'Not linked'),
        DetailLine(label: 'Flight', value: event.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: event.aircraftId ?? 'Not linked'),
        DetailLine(
          label: 'Expected volume',
          value: event.expectedVolumeId ?? 'Not provided',
        ),
        DetailLine(
          label: 'Position',
          value: event.latitude == null || event.longitude == null
              ? 'Not provided'
              : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
        ),
        DetailLine(
          label: 'Altitude',
          value: event.altitudeM == null
              ? 'Not provided'
              : '${formatMeters(event.altitudeM)} ${event.altitudeRef ?? ''}',
        ),
      ]),
    ],
  );
}
