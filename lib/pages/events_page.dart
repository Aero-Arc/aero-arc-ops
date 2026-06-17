import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<RecordsDashboard>(
      title: 'Records',
      subtitle:
          'Evidence records, reportability decisions, audit artifacts, export status, and retention posture.',
      load: AeroArcApiClient().records,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _RecordsTable(records: data.evidenceRecords),
        const SizedBox(height: 18),
        TwoColumn(
          left: _ReportabilityPanel(reviews: data.reportabilityReviews),
          right: _RetentionPanel(records: data.evidenceRecords),
        ),
      ],
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({required this.records});

  final List<EvidenceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const EmptyPanel(message: 'No evidence records are available.');
    }
    return Panel(
      title: 'Evidence Ledger',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Record')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Intent')),
              DataColumn(label: Text('Flight')),
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Object')),
            ],
            rows: [
              for (final record in records)
                DataRow(
                  onSelectChanged: (_) => _showEvidenceDetails(context, record),
                  cells: [
                    DataCell(
                      Text(
                        record.title.isEmpty ? record.id : record.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(displayEnum(record.type))),
                    DataCell(Text(record.intentId ?? 'Not provided')),
                    DataCell(Text(record.flightId ?? 'Not provided')),
                    DataCell(Text(record.aircraftId ?? 'Not provided')),
                    DataCell(StatusBadge(label: record.status)),
                    DataCell(Text(formatDate(record.createdAt))),
                    DataCell(
                      Text(
                        record.objectUri == null ? 'No object' : 'Available',
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

class _ReportabilityPanel extends StatelessWidget {
  const _ReportabilityPanel({required this.reviews});

  final List<ReportabilityReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Reportability Reviews',
      child: RowList(
        children: [
          for (final review in reviews.take(8))
            ActionRow(
              onTap: () => _showReportabilityDetails(context, review),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.trigger,
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.decision ?? 'Awaiting review',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: review.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RetentionPanel extends StatelessWidget {
  const _RetentionPanel({required this.records});

  final List<EvidenceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Retention And Integrity',
      child: RowList(
        children: [
          for (final record
              in records
                  .where(
                    (record) =>
                        record.retentionUntil != null || record.hash != null,
                  )
                  .take(8))
            ActionRow(
              onTap: () => _showEvidenceDetails(context, record),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title.isEmpty ? record.id : record.title,
                    style: const TextStyle(
                      color: Color(0xFFD6E0FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  DetailLine(
                    label: 'Retention until',
                    value: formatDate(record.retentionUntil),
                  ),
                  DetailLine(
                    label: 'Hash',
                    value: record.hash == null
                        ? 'No hash'
                        : '${record.hashAlgorithm ?? 'hash'}:${record.hash}',
                  ),
                  DetailLine(
                    label: 'Source',
                    value:
                        record.sourceSystem ??
                        record.generatedBy ??
                        'Not provided',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

void _showEvidenceDetails(BuildContext context, EvidenceRecord record) {
  showDetailsSheet(
    context,
    title: record.title.isEmpty ? record.id : record.title,
    status: StatusBadge(label: record.status),
    children: [
      detailSection('Evidence Record', [
        DetailLine(label: 'Record ID', value: record.id),
        DetailLine(label: 'Type', value: displayEnum(record.type)),
        DetailLine(label: 'Status', value: displayEnum(record.status)),
        DetailLine(label: 'Summary', value: record.summary ?? 'Not provided'),
        DetailLine(label: 'Created', value: formatDate(record.createdAt)),
        DetailLine(label: 'Updated', value: formatDate(record.updatedAt)),
      ]),
      detailSection('Links', [
        DetailLine(label: 'Intent', value: record.intentId ?? 'Not linked'),
        DetailLine(label: 'Flight', value: record.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: record.aircraftId ?? 'Not linked'),
        DetailLine(
          label: 'Object URI',
          value: record.objectUri ?? 'No object URI',
        ),
      ]),
      detailSection('Retention And Integrity', [
        DetailLine(
          label: 'Retention until',
          value: formatDate(record.retentionUntil),
        ),
        DetailLine(
          label: 'Hash',
          value: record.hash == null
              ? 'No hash'
              : '${record.hashAlgorithm ?? 'hash'}:${record.hash}',
        ),
        DetailLine(
          label: 'Schema',
          value: record.schemaVersion ?? 'Not provided',
        ),
        DetailLine(
          label: 'Generated by',
          value: record.generatedBy ?? 'Not provided',
        ),
        DetailLine(
          label: 'Source system',
          value: record.sourceSystem ?? 'Not provided',
        ),
      ]),
    ],
  );
}

void _showReportabilityDetails(
  BuildContext context,
  ReportabilityReview review,
) {
  showDetailsSheet(
    context,
    title: review.trigger,
    status: StatusBadge(label: review.status),
    children: [
      detailSection('Reportability Decision', [
        DetailLine(label: 'Review ID', value: review.id),
        DetailLine(label: 'Status', value: displayEnum(review.status)),
        DetailLine(label: 'Trigger', value: review.trigger),
        DetailLine(
          label: 'Decision',
          value: review.decision ?? 'Awaiting review',
        ),
        DetailLine(label: 'Created', value: formatDate(review.createdAt)),
        DetailLine(label: 'Resolved', value: formatDate(review.resolvedAt)),
      ]),
      detailSection('Links', [
        DetailLine(label: 'Intent', value: review.intentId ?? 'Not linked'),
        DetailLine(label: 'Flight', value: review.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: review.aircraftId ?? 'Not linked'),
        DetailLine(
          label: 'Evidence',
          value: review.evidenceRecordId ?? 'No evidence record',
        ),
      ]),
    ],
  );
}
