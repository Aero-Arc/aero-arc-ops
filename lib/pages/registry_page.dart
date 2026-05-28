import 'package:flutter/material.dart';

class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF030B1F), Color(0xFF020815)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Registry',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              'Distributed service discovery and health management',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  final cardWidth = (constraints.maxWidth - 36) / 4;
                  return Row(
                    children: [
                      _MetricCard(width: cardWidth, label: 'Total Entries', value: '8'),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Active',
                        value: '5',
                        valueColor: const Color(0xFF00CFA0),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Expiring Soon',
                        value: '2',
                        valueColor: const Color(0xFFE4A100),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Expired',
                        value: '1',
                        valueColor: const Color(0xFFE14A5B),
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _MetricCard(label: 'Total Entries', value: '8'),
                    _MetricCard(label: 'Active', value: '5', valueColor: Color(0xFF00CFA0)),
                    _MetricCard(label: 'Expiring Soon', value: '2', valueColor: Color(0xFFE4A100)),
                    _MetricCard(label: 'Expired', value: '1', valueColor: Color(0xFFE14A5B)),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const _RegistryEntriesPanel(),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return const Row(
                    children: [
                      Expanded(child: _SimplePanel(title: 'TTL Management', body: 'Policy windows, refresh cadences, and expiration controls.')),
                      SizedBox(width: 18),
                      Expanded(child: _SimplePanel(title: 'Namespace Distribution', body: 'production: 7 entries\nstaging: 1 entry')),
                    ],
                  );
                }
                return const Column(
                  children: [
                    _SimplePanel(title: 'TTL Management', body: 'Policy windows, refresh cadences, and expiration controls.'),
                    SizedBox(height: 18),
                    _SimplePanel(title: 'Namespace Distribution', body: 'production: 7 entries\nstaging: 1 entry'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.width,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 200, minHeight: 82),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1531),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF12305F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 36,
              color: valueColor ?? const Color(0xFFD6E0FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistryEntriesPanel extends StatelessWidget {
  const _RegistryEntriesPanel();

  static const rows = [
    _RegistryRow('telemetry-collector', 'node-us-west-2a-001', 'production', 59, 'Active', '2h ago'),
    _RegistryRow('mission-planner', 'node-us-east-1b-003', 'production', 48, 'Active', '3h ago'),
    _RegistryRow('data-aggregator', 'node-eu-central-1-002', 'production', 3, 'Expiring', '58m ago'),
    _RegistryRow('alert-service', 'node-us-west-1c-005', 'production', 60, 'Active', '1h ago'),
    _RegistryRow('relay-manager', 'node-ap-south-1a-004', 'staging', 1, 'Expiring', '59m ago'),
    _RegistryRow('legacy-gateway', 'node-eu-west-2b-001', 'production', -1, 'Expired', '1h ago'),
    _RegistryRow('drone-coordinator', 'node-us-west-2a-007', 'production', 52, 'Active', '2h ago'),
    _RegistryRow('health-monitor', 'node-us-east-1b-009', 'production', 44, 'Active', '3h ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08142F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF112855)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(
              'Registry Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 33),
            ),
          ),
          Container(height: 1, color: const Color(0xFF10254D)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  color: Color(0xFF7D8DB4),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                dataTextStyle: const TextStyle(color: Color(0xFFC4D0EE), fontSize: 14),
                horizontalMargin: 12,
                columnSpacing: 36,
                dividerThickness: 1,
                headingRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                dataRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                columns: const [
                  DataColumn(label: Text('Service Name')),
                  DataColumn(label: Text('Node ID')),
                  DataColumn(label: Text('Namespace')),
                  DataColumn(label: Text('TTL')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Registered')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              const Icon(Icons.storage, size: 16, color: Color(0xFF5A6BFF)),
                              const SizedBox(width: 8),
                              Text(row.serviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        DataCell(Text(row.nodeId, style: const TextStyle(color: Color(0xFF9BA9C8), fontFamily: 'monospace'))),
                        DataCell(_NamespaceBadge(value: row.namespace)),
                        DataCell(_TtlCell(ttl: row.ttl)),
                        DataCell(_StatusCell(status: row.status)),
                        DataCell(Text(row.registered, style: const TextStyle(color: Color(0xFF9BA9C8)))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamespaceBadge extends StatelessWidget {
  const _NamespaceBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x1A7D8DB4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(value, style: const TextStyle(color: Color(0xFFA6B2D0))),
    );
  }
}

class _TtlCell extends StatelessWidget {
  const _TtlCell({required this.ttl});

  final int ttl;

  @override
  Widget build(BuildContext context) {
    final isExpired = ttl < 0;
    final isWarning = ttl >= 0 && ttl <= 5;
    final color = isExpired
        ? const Color(0xFFE14A5B)
        : isWarning
            ? const Color(0xFFE4A100)
            : const Color(0xFF00CFA0);
    final text = isExpired ? 'Expired' : ttl == 60 ? '1h' : '${ttl}m';
    final ratio = isExpired ? 0.0 : (ttl / 60).clamp(0.0, 1.0);

    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: ratio,
              backgroundColor: const Color(0xFF1A2E57),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Active' => const Color(0xFF00CFA0),
      'Expiring' => const Color(0xFFE4A100),
      _ => const Color(0xFFE14A5B),
    };

    return Row(
      children: [
        Icon(Icons.circle_outlined, size: 16, color: color),
        const SizedBox(width: 8),
        Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SimplePanel extends StatelessWidget {
  const _SimplePanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08142F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF112855)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 33)),
          ),
          Container(height: 1, color: const Color(0xFF10254D)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(body, style: const TextStyle(color: Color(0xFF95A3C4), fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _RegistryRow {
  const _RegistryRow(
    this.serviceName,
    this.nodeId,
    this.namespace,
    this.ttl,
    this.status,
    this.registered,
  );

  final String serviceName;
  final String nodeId;
  final String namespace;
  final int ttl;
  final String status;
  final String registered;
}
