import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<OverviewDashboard>(
      title: 'Readiness Overview',
      subtitle:
          'Fleet readiness, operational intent posture, evidence gaps, and reportability review.',
      load: AeroArcApiClient().overview,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        TwoColumn(
          left: _AircraftReadinessPanel(aircraft: data.aircraft),
          right: _OperationsPanel(intents: data.operationalIntents),
        ),
        const SizedBox(height: 18),
        TwoColumn(
          left: _EvidencePanel(records: data.evidenceRecords),
          right: _ReportabilityPanel(reviews: data.reportabilityReviews),
        ),
      ],
    );
  }
}

class _AircraftReadinessPanel extends StatelessWidget {
  const _AircraftReadinessPanel({required this.aircraft});

  final List<AircraftDashboard> aircraft;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Aircraft Readiness',
      child: RowList(
        children: [
          for (final item in aircraft.take(6))
            ActionRow(
              onTap: () => _showAircraftOverviewDetails(context, item),
              child: Row(
                children: [
                  Expanded(
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
                        const SizedBox(height: 4),
                        Text(
                          '${item.aircraft.tailNumber} - ${item.aircraft.model}',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                        if (item.readiness.reasons.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.readiness.reasons.join(', '),
                            style: const TextStyle(
                              color: Color(0xFF8293BB),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
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

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({required this.intents});

  final List<OperationalIntent> intents;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Operational Intents',
      child: RowList(
        children: [
          for (final intent in intents.take(6))
            ActionRow(
              onTap: () => _showIntentOverviewDetails(context, intent),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.route, color: Color(0xFF6B75FF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intent.name.isEmpty ? intent.id : intent.name,
                          style: const TextStyle(
                            color: Color(0xFFD6E0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${intent.id} - ${formatDate(intent.plannedStartAt)}',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: intent.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.records});

  final List<EvidenceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Evidence Records',
      child: RowList(
        children: [
          for (final record in records.take(6))
            ActionRow(
              onTap: () => _showEvidenceOverviewDetails(context, record),
              child: Row(
                children: [
                  Expanded(
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
                        const SizedBox(height: 4),
                        Text(
                          '${displayEnum(record.type)} - ${formatDate(record.createdAt)}',
                          style: const TextStyle(color: Color(0xFF93A3C7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: record.status),
                ],
              ),
            ),
        ],
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
      title: 'Reportability Queue',
      child: RowList(
        children: [
          for (final review in reviews.take(6))
            ActionRow(
              onTap: () => _showReportabilityOverviewDetails(context, review),
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
                          review.decision ?? 'Awaiting decision',
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

void _showAircraftOverviewDetails(
  BuildContext context,
  AircraftDashboard item,
) {
  showDetailsSheet(
    context,
    title: item.aircraft.displayName,
    status: StatusBadge(label: item.readiness.status),
    children: [
      detailSection('Readiness', [
        DetailLine(label: 'Status', value: displayEnum(item.readiness.status)),
        DetailLine(
          label: 'Reasons',
          value: item.readiness.reasons.isEmpty
              ? 'No readiness blockers reported.'
              : item.readiness.reasons.join('\n'),
        ),
        DetailLine(
          label: 'Battery',
          value: item.activeBattery == null
              ? 'No active battery'
              : '${item.activeBattery!.serialNumber} ${formatPercent(item.activeBattery!.stateOfHealth)} SOH',
        ),
        DetailLine(
          label: 'Live state',
          value: item.liveStateAvailable ? 'Available' : 'Unavailable',
        ),
      ]),
    ],
  );
}

void _showIntentOverviewDetails(
  BuildContext context,
  OperationalIntent intent,
) {
  showDetailsSheet(
    context,
    title: intent.name.isEmpty ? intent.id : intent.name,
    status: StatusBadge(label: intent.status),
    children: [
      detailSection('Operation', [
        DetailLine(label: 'Intent ID', value: intent.id),
        DetailLine(label: 'Aircraft', value: intent.aircraftId),
        DetailLine(label: 'Summary', value: intent.summary),
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
          label: 'Altitude',
          value: formatFeetRange(
            intent.minAltitudeFtAgl,
            intent.maxAltitudeFtAgl,
          ),
        ),
        DetailLine(
          label: 'Authorization',
          value: displayEnum(intent.authorizationPath),
        ),
        DetailLine(
          label: 'Conformance required',
          value: yesNo(intent.conformanceRequired),
        ),
      ]),
    ],
  );
}

void _showEvidenceOverviewDetails(BuildContext context, EvidenceRecord record) {
  showDetailsSheet(
    context,
    title: record.title.isEmpty ? record.id : record.title,
    status: StatusBadge(label: record.status),
    children: [
      detailSection('Evidence', [
        DetailLine(label: 'Record ID', value: record.id),
        DetailLine(label: 'Type', value: displayEnum(record.type)),
        DetailLine(label: 'Summary', value: record.summary ?? 'Not provided'),
        DetailLine(label: 'Intent', value: record.intentId ?? 'Not linked'),
        DetailLine(label: 'Flight', value: record.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: record.aircraftId ?? 'Not linked'),
        DetailLine(label: 'Object', value: record.objectUri ?? 'No object URI'),
        DetailLine(
          label: 'Retention until',
          value: formatDate(record.retentionUntil),
        ),
      ]),
    ],
  );
}

void _showReportabilityOverviewDetails(
  BuildContext context,
  ReportabilityReview review,
) {
  showDetailsSheet(
    context,
    title: review.trigger,
    status: StatusBadge(label: review.status),
    children: [
      detailSection('Reportability Review', [
        DetailLine(label: 'Review ID', value: review.id),
        DetailLine(label: 'Trigger', value: review.trigger),
        DetailLine(
          label: 'Decision',
          value: review.decision ?? 'Awaiting decision',
        ),
        DetailLine(label: 'Intent', value: review.intentId ?? 'Not linked'),
        DetailLine(label: 'Flight', value: review.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: review.aircraftId ?? 'Not linked'),
        DetailLine(
          label: 'Evidence',
          value: review.evidenceRecordId ?? 'No evidence record',
        ),
        DetailLine(label: 'Resolved', value: formatDate(review.resolvedAt)),
      ]),
    ],
  );
}
