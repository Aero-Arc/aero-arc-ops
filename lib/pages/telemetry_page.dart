import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class TelemetryPage extends StatefulWidget {
  const TelemetryPage({
    super.key,
    this.apiClient,
    this.enableSampleEvaluation = const bool.fromEnvironment(
      'AERO_ARC_ENABLE_SAMPLE_CONFORMANCE',
    ),
  });

  final AeroArcApiClient? apiClient;
  final bool enableSampleEvaluation;

  @override
  State<TelemetryPage> createState() => _TelemetryPageState();
}

class _TelemetryPageState extends State<TelemetryPage> {
  late final AeroArcApiClient _apiClient;
  ConformanceEvaluation? _latestEvaluation;
  var _refreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AeroArcApiClient();
  }

  Future<void> _openConformanceCheck() async {
    final result = await showModalBottomSheet<ConformanceEvaluation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF07132E),
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => _ConformanceCheckSheet(apiClient: _apiClient),
    );
    if (!mounted || result == null) return;
    setState(() {
      _latestEvaluation = result;
      _refreshTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage<ConformanceDashboard>(
      title: 'Conformance',
      subtitle:
          'Live assignment condition, monitoring freshness, recording durability, and deviation history.',
      load: _apiClient.conformance,
      autoRefreshInterval: const Duration(seconds: 3),
      refreshTrigger: _refreshTrigger,
      headerActions: [
        if (widget.enableSampleEvaluation)
          FilledButton.tonalIcon(
            onPressed: _openConformanceCheck,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Evaluate API sample'),
          ),
      ],
      builder: (context, data) {
        DashboardMetric? scoringNotice;
        final primaryMetrics = <DashboardMetric>[];
        for (final metric in data.metrics) {
          if (metric.label.toLowerCase() == 'target conformance' &&
              metric.value.toLowerCase() == 'not scored') {
            scoringNotice = metric;
          } else {
            primaryMetrics.add(metric);
          }
        }
        final summaries = [...data.summaries]
          ..sort(_compareConformanceSummaries);
        final events = [...data.events]..sort(_compareConformanceEvents);
        final hasDashboardData =
            data.metrics.isNotEmpty ||
            summaries.isNotEmpty ||
            events.isNotEmpty;
        return [
          if (_latestEvaluation case final evaluation?) ...[
            _EvaluationResultPanel(evaluation: evaluation),
            const SizedBox(height: 18),
          ],
          if (!hasDashboardData)
            const EmptyPanel(
              message:
                  'No monitored operations or conformance findings are available.',
            )
          else ...[
            if (scoringNotice != null) ...[
              _ScoringNotice(metric: scoringNotice),
              const SizedBox(height: 12),
            ],
            if (primaryMetrics.isNotEmpty) ...[
              MetricGrid(metrics: primaryMetrics),
              const SizedBox(height: 18),
            ],
            TwoColumn(
              left: _SummaryPanel(summaries: summaries),
              right: _EventTimeline(events: events),
            ),
            if (summaries.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ConformanceTable(summaries: summaries),
            ],
          ],
        ];
      },
    );
  }
}

class _ScoringNotice extends StatelessWidget {
  const _ScoringNotice({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${metric.label}: ${metric.value}. ${metric.detail ?? 'Live condition is reported separately.'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1531),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF12305F)),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: 19,
                color: Color(0xFF91A0FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${metric.label}: ${metric.value} · ${metric.detail ?? 'Live condition is reported separately'}',
                style: const TextStyle(color: Color(0xFFB7C4E5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConformanceCheckSheet extends StatefulWidget {
  const _ConformanceCheckSheet({required this.apiClient});

  final AeroArcApiClient apiClient;

  @override
  State<_ConformanceCheckSheet> createState() => _ConformanceCheckSheetState();
}

class _ConformanceCheckSheetState extends State<_ConformanceCheckSheet> {
  final _formKey = GlobalKey<FormState>();
  final _aircraftId = TextEditingController();
  final _intentId = TextEditingController();
  final _flightId = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _altitudeM = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _aircraftId.dispose();
    _intentId.dispose();
    _flightId.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _altitudeM.dispose();
    super.dispose();
  }

  Future<void> _evaluate() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    final now = DateTime.now().toUtc();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final evaluation = await widget.apiClient.evaluateTelemetry(
        TelemetrySample(
          id: 'ops-check-${now.microsecondsSinceEpoch}',
          aircraftId: _aircraftId.text.trim(),
          intentId: _optionalText(_intentId.text),
          flightId: _optionalText(_flightId.text),
          recordedAt: now,
          latitude: double.parse(_latitude.text.trim()),
          longitude: double.parse(_longitude.text.trim()),
          altitudeM: double.parse(_altitudeM.text.trim()),
          velocityMps: 0,
          headingDeg: 0,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(evaluation);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        20,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Run conformance check',
                    style: TextStyle(
                      color: Color(0xFFD6E0FF),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit one telemetry position for evaluation against an active operational intent. The API persists this sample and may create a conformance event.',
              style: TextStyle(color: Color(0xFF93A3C7), height: 1.4),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 2 : 1;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _aircraftId,
                        label: 'Aircraft ID',
                        validator: _requiredValue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _intentId,
                        label: 'Intent ID (optional)',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _flightId,
                        label: 'Flight ID (optional)',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _altitudeM,
                        label: 'Altitude (m AGL)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: _numberInRange(label: 'Altitude'),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _latitude,
                        label: 'Latitude',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: _numberInRange(
                          label: 'Latitude',
                          min: -90,
                          max: 90,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _CheckField(
                        controller: _longitude,
                        label: 'Longitude',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: _numberInRange(
                          label: 'Longitude',
                          min: -180,
                          max: 180,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 16),
              _CheckError(message: error),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : _evaluate,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_busy ? 'Checking…' : 'Evaluate sample'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckField extends StatelessWidget {
  const _CheckField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: true,
      style: const TextStyle(color: Color(0xFFC9D5F4)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF06122C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _CheckError extends StatelessWidget {
  const _CheckError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x331E4A5B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x99E14A5B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE14A5B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Check failed',
                    style: TextStyle(
                      color: Color(0xFFF2B8BF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFFD8A6AD)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationResultPanel extends StatelessWidget {
  const _EvaluationResultPanel({required this.evaluation});

  final ConformanceEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final summary = evaluation.summary;
    final eventCount = evaluation.events.length;
    return Panel(
      title: 'Latest Check Result',
      trailing: StatusBadge(label: summary.status),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${evaluation.intent.id} v${evaluation.intent.version} · Aircraft ${summary.aircraftId}',
              style: const TextStyle(
                color: Color(0xFFD6E0FF),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('Score: ${formatPercent(summary.score)}'),
                Text('Alerts: ${summary.alertCount}'),
                Text(
                  'Reportability: ${displayEnum(summary.reportabilityStatus)}',
                ),
                Text('Summary updated: ${formatDate(summary.updatedAt)}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              eventCount == 0
                  ? 'No new deviation event was created.'
                  : '$eventCount new deviation event${eventCount == 1 ? '' : 's'} created.',
              style: TextStyle(color: statusColor(summary.status)),
            ),
          ],
        ),
      ),
    );
  }
}

String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _requiredValue(String? value) {
  return value == null || value.trim().isEmpty ? 'Required' : null;
}

FormFieldValidator<String> _numberInRange({
  required String label,
  double? min,
  double? max,
}) {
  return (value) {
    final requiredError = _requiredValue(value);
    if (requiredError != null) return requiredError;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null || !parsed.isFinite) return 'Enter a valid number';
    if (min != null && parsed < min || max != null && parsed > max) {
      return '$label must be between $min and $max';
    }
    return null;
  };
}

int _compareConformanceSummaries(
  ConformanceSummary left,
  ConformanceSummary right,
) {
  final condition = _conditionPriority(
    _summaryCondition(right),
  ).compareTo(_conditionPriority(_summaryCondition(left)));
  if (condition != 0) return condition;
  final monitoring = _monitoringPriority(
    right.monitoringStatus,
  ).compareTo(_monitoringPriority(left.monitoringStatus));
  if (monitoring != 0) return monitoring;
  final reportability = _reportabilityPriority(
    right.reportabilityStatus,
  ).compareTo(_reportabilityPriority(left.reportabilityStatus));
  if (reportability != 0) return reportability;
  final alerts = right.alertCount.compareTo(left.alertCount);
  if (alerts != 0) return alerts;
  return _compareNewest(left.updatedAt, right.updatedAt);
}

int _conditionPriority(String status) => switch (status) {
  'non_conforming' => 5,
  'suspected' => 4,
  'recovering' => 3,
  'unknown' => 2,
  'conforming' => 1,
  _ => 0,
};

int _monitoringPriority(String? status) => switch (status) {
  'unavailable' => 4,
  'stale' => 3,
  'armed' || 'received' => 2,
  'current' => 1,
  _ => 0,
};

int _compareConformanceEvents(ConformanceEvent left, ConformanceEvent right) {
  final severity = _severityPriority(
    right.severity,
  ).compareTo(_severityPriority(left.severity));
  if (severity != 0) return severity;
  return _compareNewest(left.occurredAt, right.occurredAt);
}

int _compareNewest(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return right.compareTo(left);
}

int _reportabilityPriority(String status) => switch (status) {
  'reportable' => 3,
  'review' => 2,
  'no' => 1,
  _ => 0,
};

int _severityPriority(String status) => switch (status) {
  'critical' || 'emergency' => 3,
  'warning' => 2,
  'advisory' => 1,
  _ => 0,
};

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summaries});

  final List<ConformanceSummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Conformance Summaries',
      child: summaries.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No conformance summaries are available.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              ),
            )
          : RowList(
              children: [
                for (final summary in summaries.take(8))
                  ActionRow(
                    onTap: () =>
                        _showConformanceSummaryDetails(context, summary),
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
                                summary.isLiveProjection
                                    ? '${summary.aircraftId} · ${displayEnum(summary.monitoringStatus ?? 'unknown')} monitoring · ${displayEnum(summary.recordingStatus ?? 'unknown')} recording\nObserved ${_conformanceAge(summary.observedAt ?? summary.updatedAt)} · ${summary.activeViolationCount} active findings'
                                    : '${summary.aircraftId} · ${formatPercent(summary.score)} · ${summary.alertCount} alerts',
                                style: const TextStyle(
                                  color: Color(0xFF93A3C7),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(label: _summaryCondition(summary)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

String _conformanceAge(DateTime? observedAt) {
  if (observedAt == null) return 'time unavailable';
  final age = DateTime.now().toUtc().difference(observedAt.toUtc());
  if (age.isNegative || age.inSeconds < 1) return 'now';
  if (age.inSeconds < 60) return '${age.inSeconds}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 48) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.events});

  final List<ConformanceEvent> events;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Deviation Timeline',
      child: events.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No conformance deviations are available.',
                style: TextStyle(color: Color(0xFF93A3C7)),
              ),
            )
          : RowList(
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
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Condition')),
              DataColumn(label: Text('Monitoring')),
              DataColumn(label: Text('Recording')),
              DataColumn(label: Text('Findings')),
              DataColumn(label: Text('Observed')),
            ],
            rows: [
              for (final summary in summaries)
                DataRow(
                  onSelectChanged: (_) =>
                      _showConformanceSummaryDetails(context, summary),
                  cells: [
                    DataCell(Text(summary.intentId)),
                    DataCell(Text(summary.aircraftId)),
                    DataCell(StatusBadge(label: _summaryCondition(summary))),
                    DataCell(
                      summary.monitoringStatus == null
                          ? const Text('Legacy check')
                          : StatusBadge(label: summary.monitoringStatus!),
                    ),
                    DataCell(
                      summary.recordingStatus == null
                          ? const Text('Not reported')
                          : StatusBadge(label: summary.recordingStatus!),
                    ),
                    DataCell(
                      Text(
                        '${summary.isLiveProjection ? summary.activeViolationCount : summary.alertCount}',
                      ),
                    ),
                    DataCell(
                      Text(formatDate(summary.observedAt ?? summary.updatedAt)),
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

void _showConformanceSummaryDetails(
  BuildContext context,
  ConformanceSummary summary,
) {
  showDetailsSheet(
    context,
    title: summary.intentId,
    status: StatusBadge(label: _summaryCondition(summary)),
    children: [
      detailSection('Conformance Summary', [
        DetailLine(label: 'Summary ID', value: summary.id),
        DetailLine(
          label: 'Condition',
          value: displayEnum(_summaryCondition(summary)),
        ),
        DetailLine(
          label: 'Monitoring',
          value: summary.monitoringStatus == null
              ? 'Legacy API evaluation'
              : displayEnum(summary.monitoringStatus!),
        ),
        DetailLine(
          label: 'Recording',
          value: summary.recordingStatus == null
              ? 'Not reported'
              : displayEnum(summary.recordingStatus!),
        ),
        DetailLine(
          label: 'Observed',
          value: formatDate(summary.observedAt ?? summary.updatedAt),
        ),
      ]),
      if (summary.activeViolations.isNotEmpty)
        detailSection('Active Findings', [
          for (final violation in summary.activeViolations)
            DetailLine(
              label: displayEnum(violation.type),
              value:
                  '${displayEnum(violation.phase)} · worst ${formatMeters(violation.worstDeviationM)} · last ${formatDate(violation.lastObservedAt)}',
            ),
        ]),
      if (summary.isLiveProjection)
        detailSection('Evaluation Identity', [
          DetailLine(
            label: 'Assignment',
            value: summary.assignmentId ?? 'Not provided',
          ),
          DetailLine(
            label: 'Generation',
            value: '${summary.assignmentGeneration ?? 0}',
          ),
          DetailLine(
            label: 'Evaluation revision',
            value: '${summary.evaluationRevision ?? 0}',
          ),
          DetailLine(
            label: 'Evaluation ID',
            value: summary.evaluationId ?? 'Not provided',
          ),
          DetailLine(
            label: 'Frame ID',
            value: summary.frameId ?? 'Not provided',
          ),
        ]),
      if (!summary.isLiveProjection)
        detailSection('Legacy Evaluation', [
          DetailLine(label: 'Score', value: formatPercent(summary.score)),
          DetailLine(label: 'Alert count', value: '${summary.alertCount}'),
          DetailLine(
            label: 'Reportability',
            value: displayEnum(summary.reportabilityStatus),
          ),
        ]),
      if (summary.isLiveProjection && summary.violations.isNotEmpty)
        detailSection('Evaluated Axes', [
          for (final violation in summary.violations)
            DetailLine(
              label: displayEnum(violation.type),
              value: displayEnum(violation.phase),
            ),
        ]),
      detailSection('Links', [
        DetailLine(
          label: 'Intent',
          value: '${summary.intentId} v${summary.intentVersion}',
        ),
        DetailLine(label: 'Flight', value: summary.flightId ?? 'Not linked'),
        DetailLine(label: 'Aircraft', value: summary.aircraftId),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: () => _openAircraftMap(context, summary.aircraftId),
          icon: const Icon(Icons.map_outlined),
          label: const Text('View aircraft map'),
        ),
      ),
    ],
  );
}

String _summaryCondition(ConformanceSummary summary) {
  final condition = summary.condition;
  return condition == null || condition.isEmpty ? summary.status : condition;
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
      if (event.aircraftId case final aircraftId?)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _openAircraftMap(context, aircraftId),
            icon: const Icon(Icons.map_outlined),
            label: const Text('View aircraft map'),
          ),
        ),
    ],
  );
}

void _openAircraftMap(BuildContext context, String aircraftId) {
  Navigator.of(context)
    ..pop()
    ..pushNamed('/aircraft/${Uri.encodeComponent(aircraftId)}/map');
}
