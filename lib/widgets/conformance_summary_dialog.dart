import 'package:flutter/material.dart';

import '../models/aero_arc_models.dart';
import 'dashboard_ui.dart';
import 'conformance_evidence_field.dart';
import 'operational_selection.dart';

/// Operational summary snapshot, with source identity disclosed on demand.
class ConformanceSummaryDialog extends StatelessWidget {
  const ConformanceSummaryDialog({
    super.key,
    required this.summary,
    required this.condition,
    required this.axes,
  });
  final ConformanceSummary summary;
  final String condition;
  final Map<String, String> axes;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF101821),
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFF293847)),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    size: 20,
                    color: Color(0xFF27D8EF),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'CONFORMANCE SUMMARY',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: Color(0xFF8797AB),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close summary',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                operationName(context, summary.intentId, summary.aircraftId),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${summary.aircraftId} · Intent ${shortOperationalId(summary.intentId)} · v${summary.intentVersion}',
              ),
              TextButton.icon(
                onPressed: () => focusOperation(
                  context,
                  summary.aircraftId,
                  intentId: summary.intentId,
                  closeDialog: true,
                ),
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Focus in Overview'),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  StatusBadge(label: condition),
                  Text(
                    '${summary.isLiveProjection ? summary.activeViolationCount : summary.alertCount} active findings',
                    style: const TextStyle(
                      color: Color(0xFFA0ADBB),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1219),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF293847)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(
                      'Monitoring',
                      summary.monitoringStatus == null
                          ? 'Legacy API evaluation'
                          : displayEnum(summary.monitoringStatus!),
                    ),
                    _line(
                      'Recording',
                      summary.recordingStatus == null
                          ? 'Not reported'
                          : displayEnum(summary.recordingStatus!),
                    ),
                    _line(
                      'Observed',
                      formatDate(summary.observedAt ?? summary.updatedAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Evaluation at this observation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final axis in axes.entries)
                _line(displayEnum(axis.key), axis.value),
              if (axes.isEmpty)
                const Text(
                  'No axis evidence reported.',
                  style: TextStyle(color: Color(0xFF8797AB)),
                ),
              if (summary.violationFor('temporal_deviation')
                  case final temporal?)
                if (temporal.phase != 'clear' && temporal.openedAt != null)
                  _line('Timing finding opened', formatDate(temporal.openedAt)),
              const SizedBox(height: 12),
              ConformanceEvidenceField(
                label: 'Flight',
                value: summary.flightId ?? 'Not linked',
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                title: const Text(
                  'Evaluation evidence',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Operation, assignment and source identifiers',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
                ),
                children: [
                  ConformanceEvidenceField(
                    label: 'Summary ID',
                    value: summary.id,
                  ),
                  ConformanceEvidenceField(
                    label: 'Operation',
                    value: summary.intentId,
                  ),
                  ConformanceEvidenceField(
                    label: 'Intent version',
                    value: '${summary.intentVersion}',
                  ),
                  if (summary.isLiveProjection) ...[
                    ConformanceEvidenceField(
                      label: 'Assignment',
                      value: summary.assignmentId ?? 'Not reported',
                    ),
                    ConformanceEvidenceField(
                      label: 'Generation',
                      value:
                          summary.assignmentGeneration?.toString() ??
                          'Not reported',
                    ),
                    ConformanceEvidenceField(
                      label: 'Evaluation revision',
                      value:
                          summary.evaluationRevision?.toString() ??
                          'Not reported',
                    ),
                    ConformanceEvidenceField(
                      label: 'Evaluation ID',
                      value: summary.evaluationId ?? 'Not reported',
                    ),
                    ConformanceEvidenceField(
                      label: 'Frame ID',
                      value: summary.frameId ?? 'Not reported',
                    ),
                  ] else ...[
                    ConformanceEvidenceField(
                      label: 'Score',
                      value: formatPercent(summary.score),
                    ),
                    ConformanceEvidenceField(
                      label: 'Reportability',
                      value: displayEnum(summary.reportabilityStatus),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Snapshot at opening. Monitoring freshness and recording status are separate from condition.',
                style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.pushNamed(
                    '/aircraft/${Uri.encodeComponent(summary.aircraftId)}/map',
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('View aircraft map'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _line(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      SizedBox(
        width: 150,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8797AB)),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 13, color: Color(0xFFD3DDE7)),
      ),
    ],
  ),
);
