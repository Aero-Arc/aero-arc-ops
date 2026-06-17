import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class NodesPage extends StatelessWidget {
  const NodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardPage<PreflightDashboard>(
      title: 'Preflight',
      subtitle:
          'Auditable launch checks for weather, airspace, aircraft, personnel, cybersecurity, and blockers.',
      load: AeroArcApiClient().preflight,
      builder: (context, data) => [
        MetricGrid(metrics: data.metrics),
        const SizedBox(height: 18),
        _PreflightTable(checks: data.checks),
        const SizedBox(height: 18),
        TwoColumn(
          left: _BlockingPanel(checks: data.checks),
          right: _CategoryPanel(checks: data.checks),
        ),
      ],
    );
  }
}

class _PreflightTable extends StatelessWidget {
  const _PreflightTable({required this.checks});

  final List<PreflightCheck> checks;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) {
      return const EmptyPanel(message: 'No preflight checks are available.');
    }
    return Panel(
      title: 'Check Register',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Intent')),
              DataColumn(label: Text('Aircraft')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Blocking')),
              DataColumn(label: Text('Valid Until')),
              DataColumn(label: Text('Evidence')),
            ],
            rows: [
              for (final check in checks)
                DataRow(
                  onSelectChanged: (_) =>
                      _showPreflightCheckDetails(context, check),
                  cells: [
                    DataCell(Text(check.intentId)),
                    DataCell(Text(check.aircraftId ?? 'Not provided')),
                    DataCell(Text(displayEnum(check.category))),
                    DataCell(Text(check.source)),
                    DataCell(StatusBadge(label: check.status)),
                    DataCell(
                      StatusBadge(label: check.blocking ? 'blocked' : 'clear'),
                    ),
                    DataCell(Text(formatDate(check.validUntil))),
                    DataCell(Text(check.evidenceRecordId ?? 'No evidence')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockingPanel extends StatelessWidget {
  const _BlockingPanel({required this.checks});

  final List<PreflightCheck> checks;

  @override
  Widget build(BuildContext context) {
    final blocking = checks
        .where(
          (c) => c.blocking || c.status == 'blocked' || c.status == 'action',
        )
        .toList();
    return Panel(
      title: 'Blocking Items',
      child: RowList(
        children: [
          for (final check in blocking.take(8))
            ActionRow(
              onTap: () => _showPreflightCheckDetails(context, check),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${displayEnum(check.category)}: ${check.summary}',
                      style: const TextStyle(
                        color: Color(0xFFC4D0EE),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: check.status),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.checks});

  final List<PreflightCheck> checks;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final check in checks) {
      counts.update(check.category, (value) => value + 1, ifAbsent: () => 1);
    }
    return Panel(
      title: 'Check Coverage',
      child: RowList(
        children: [
          for (final entry in counts.entries)
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayEnum(entry.key),
                    style: const TextStyle(
                      color: Color(0xFFD6E0FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    color: Color(0xFFC4D0EE),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void _showPreflightCheckDetails(BuildContext context, PreflightCheck check) {
  showDetailsSheet(
    context,
    title: '${displayEnum(check.category)} check',
    status: StatusBadge(label: check.status),
    children: [
      detailSection('Why This Check Matters', [
        DetailLine(label: 'Status', value: displayEnum(check.status)),
        DetailLine(label: 'Blocking dispatch', value: yesNo(check.blocking)),
        DetailLine(label: 'Summary', value: check.summary),
        DetailLine(
          label: 'Requirement',
          value: check.requirementCode ?? 'Not provided',
        ),
        DetailLine(
          label: 'Rule version',
          value: check.ruleVersion ?? 'Not provided',
        ),
      ]),
      detailSection('Scope And Evidence', [
        DetailLine(
          label: 'Intent',
          value: '${check.intentId} v${check.intentVersion}',
        ),
        DetailLine(label: 'Aircraft', value: check.aircraftId ?? 'Not linked'),
        DetailLine(label: 'Source', value: check.source),
        DetailLine(label: 'Valid until', value: formatDate(check.validUntil)),
        DetailLine(label: 'Captured', value: formatDate(check.capturedAt)),
        DetailLine(
          label: 'Raw data',
          value: check.rawDataUri ?? 'No raw data URI',
        ),
        DetailLine(
          label: 'Evidence',
          value: check.evidenceRecordId ?? 'No evidence record',
        ),
      ]),
    ],
  );
}
