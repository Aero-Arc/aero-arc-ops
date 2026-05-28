import 'package:flutter/material.dart';

class NodesPage extends StatelessWidget {
  const NodesPage({super.key});

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
              'Compute Nodes',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              'Infrastructure node monitoring and resource utilization',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  final cardWidth = (constraints.maxWidth - 36) / 4;
                  return Row(
                    children: [
                      _MetricCard(width: cardWidth, label: 'Total Nodes', value: '5'),
                      const SizedBox(width: 12),
                      _MetricCard(width: cardWidth, label: 'Avg CPU', value: '49%'),
                      const SizedBox(width: 12),
                      _MetricCard(width: cardWidth, label: 'Avg Memory', value: '65%'),
                      const SizedBox(width: 12),
                      _MetricCard(width: cardWidth, label: 'Avg Disk', value: '45%'),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _MetricCard(label: 'Total Nodes', value: '5'),
                    _MetricCard(label: 'Avg CPU', value: '49%'),
                    _MetricCard(label: 'Avg Memory', value: '65%'),
                    _MetricCard(label: 'Avg Disk', value: '45%'),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const _NodeStatusPanel(),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1200) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _UtilizationPanel(
                          title: 'CPU Utilization',
                          icon: Icons.memory,
                          valueColor: Color(0xFF5B6BFF),
                          rows: _NodeStatusPanel.rows,
                          selector: _cpuSelector,
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: _UtilizationPanel(
                          title: 'Memory Utilization',
                          icon: Icons.sd_storage,
                          valueColor: Color(0xFFE4A100),
                          rows: _NodeStatusPanel.rows,
                          selector: _memorySelector,
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: _UtilizationPanel(
                          title: 'Disk Utilization',
                          icon: Icons.storage,
                          valueColor: Color(0xFF00CFA0),
                          rows: _NodeStatusPanel.rows,
                          selector: _diskSelector,
                        ),
                      ),
                    ],
                  );
                }

                return const Column(
                  children: [
                    _UtilizationPanel(
                      title: 'CPU Utilization',
                      icon: Icons.memory,
                      valueColor: Color(0xFF5B6BFF),
                      rows: _NodeStatusPanel.rows,
                      selector: _cpuSelector,
                    ),
                    SizedBox(height: 18),
                    _UtilizationPanel(
                      title: 'Memory Utilization',
                      icon: Icons.sd_storage,
                      valueColor: Color(0xFFE4A100),
                      rows: _NodeStatusPanel.rows,
                      selector: _memorySelector,
                    ),
                    SizedBox(height: 18),
                    _UtilizationPanel(
                      title: 'Disk Utilization',
                      icon: Icons.storage,
                      valueColor: Color(0xFF00CFA0),
                      rows: _NodeStatusPanel.rows,
                      selector: _diskSelector,
                    ),
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
  const _MetricCard({required this.label, required this.value, this.width});

  final String label;
  final String value;
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 36,
              color: const Color(0xFFD6E0FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeStatusPanel extends StatelessWidget {
  const _NodeStatusPanel();

  static const rows = [
    _NodeRow('node-us-west-2a-001', 'aero-west-2a-001.internal', 'Healthy', 45, 62, 38, 'us-west-2a', '18d 5h'),
    _NodeRow('node-us-east-1b-003', 'aero-east-1b-003.internal', 'Healthy', 32, 54, 42, 'us-east-1b', '22d 8h'),
    _NodeRow('node-eu-central-1-002', 'aero-eu-c1-002.internal', 'Degraded', 88, 91, 67, 'eu-central-1', '8d 12h'),
    _NodeRow('node-ap-south-1a-004', 'aero-ap-s1a-004.internal', 'Healthy', 28, 48, 35, 'ap-south-1a', '15d 3h'),
    _NodeRow('node-us-west-1c-005', 'aero-west-1c-005.internal', 'Healthy', 52, 68, 44, 'us-west-1c', '12d 1h'),
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
              'Node Status',
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
                columnSpacing: 30,
                dividerThickness: 1,
                headingRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                dataRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                columns: const [
                  DataColumn(label: Text('Node ID')),
                  DataColumn(label: Text('Hostname')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('CPU')),
                  DataColumn(label: Text('Memory')),
                  DataColumn(label: Text('Disk')),
                  DataColumn(label: Text('Region')),
                  DataColumn(label: Text('Uptime')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(row.nodeId, style: const TextStyle(fontFamily: 'monospace'))),
                        DataCell(Text(row.hostname, style: const TextStyle(color: Color(0xFF9BA9C8)))),
                        DataCell(_StatusBadge(status: row.status)),
                        DataCell(_PercentValue(icon: Icons.memory, value: row.cpu, color: _cpuColor(row.cpu))),
                        DataCell(
                          _PercentValue(
                            icon: Icons.sd_storage,
                            value: row.memory,
                            color: _memoryColor(row.memory),
                          ),
                        ),
                        DataCell(
                          _PercentValue(icon: Icons.storage, value: row.disk, color: _diskColor(row.disk)),
                        ),
                        DataCell(Text(row.region, style: const TextStyle(color: Color(0xFF9BA9C8)))),
                        DataCell(Text(row.uptime)),
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

class _UtilizationPanel extends StatelessWidget {
  const _UtilizationPanel({
    required this.title,
    required this.icon,
    required this.valueColor,
    required this.rows,
    required this.selector,
  });

  final String title;
  final IconData icon;
  final Color valueColor;
  final List<_NodeRow> rows;
  final int Function(_NodeRow row) selector;

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
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 33),
            ),
          ),
          Container(height: 1, color: const Color(0xFF10254D)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              children: [
                for (final row in rows) ...[
                  _UtilizationRow(
                    icon: icon,
                    label: row.nodeId,
                    value: selector(row),
                    valueColor: valueColor,
                  ),
                  if (row != rows.last) const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilizationRow extends StatelessWidget {
  const _UtilizationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF5B6BFF)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8EA0C5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value%',
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: const Color(0xFF1A2A4F)),
                FractionallySizedBox(
                  widthFactor: value / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          valueColor.withValues(alpha: 0.85),
                          valueColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Healthy' ? const Color(0xFF00CFA0) : const Color(0xFFE4A100);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PercentValue extends StatelessWidget {
  const _PercentValue({required this.icon, required this.value, required this.color});

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF5B6BFF)),
        const SizedBox(width: 8),
        Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

Color _cpuColor(int value) => value >= 80 ? const Color(0xFFE14A5B) : const Color(0xFF00CFA0);

Color _memoryColor(int value) => value >= 85 ? const Color(0xFFE14A5B) : const Color(0xFFE4A100);

Color _diskColor(int value) => value >= 75 ? const Color(0xFFE4A100) : const Color(0xFF00CFA0);

int _cpuSelector(_NodeRow row) => row.cpu;

int _memorySelector(_NodeRow row) => row.memory;

int _diskSelector(_NodeRow row) => row.disk;

class _NodeRow {
  const _NodeRow(
    this.nodeId,
    this.hostname,
    this.status,
    this.cpu,
    this.memory,
    this.disk,
    this.region,
    this.uptime,
  );

  final String nodeId;
  final String hostname;
  final String status;
  final int cpu;
  final int memory;
  final int disk;
  final String region;
  final String uptime;
}
