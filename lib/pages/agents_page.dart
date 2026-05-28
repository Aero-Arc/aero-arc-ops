import 'package:flutter/material.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

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
              'Agents',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor and manage agent operations',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1200) {
                  final cardWidth = (constraints.maxWidth - 48) / 5;
                  return Row(
                    children: [
                      _MetricCard(width: cardWidth, label: 'Total Agents', value: '48'),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Active',
                        value: '3',
                        valueColor: const Color(0xFF00CFA0),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(width: cardWidth, label: 'Idle', value: '42'),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Returning',
                        value: '2',
                        valueColor: const Color(0xFF4092FF),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Maintenance',
                        value: '1',
                        valueColor: const Color(0xFFE4A100),
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _MetricCard(label: 'Total Agents', value: '48'),
                    _MetricCard(label: 'Active', value: '3', valueColor: Color(0xFF00CFA0)),
                    _MetricCard(label: 'Idle', value: '42'),
                    _MetricCard(label: 'Returning', value: '2', valueColor: Color(0xFF4092FF)),
                    _MetricCard(label: 'Maintenance', value: '1', valueColor: Color(0xFFE4A100)),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const _FleetStatusPanel(),
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14),
          ),
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

class _FleetStatusPanel extends StatelessWidget {
  const _FleetStatusPanel();

  static const _rows = [
    _AgentRow('EAGLE-7', 87, 92, 'Active', '1s ago'),
    _AgentRow('FALCON-3', 45, 78, 'Returning', '2s ago'),
    _AgentRow('HAWK-12', 92, 95, 'Idle', '1s ago'),
    _AgentRow('RAVEN-5', 15, 45, 'Maintenance', '45s ago'),
    _AgentRow('OSPREY-9', 68, 88, 'Active', '1s ago'),
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
              'Fleet Status',
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
                columnSpacing: 38,
                dividerThickness: 1,
                headingRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                dataRowColor: const WidgetStatePropertyAll(Color(0xFF0A1531)),
                columns: const [
                  DataColumn(label: Text('Callsign')),
                  DataColumn(label: Text('Battery')),
                  DataColumn(label: Text('Link')),
                  DataColumn(label: Text('Mission State')),
                  DataColumn(label: Text('Last Telemetry')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final row in _rows)
                    DataRow(
                      cells: [
                        DataCell(Text(row.callsign, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(_BatteryCell(percent: row.battery)),
                        DataCell(_LinkCell(percent: row.link)),
                        DataCell(_MissionBadge(state: row.state)),
                        DataCell(Text(row.lastTelemetry)),
                        const DataCell(Text('Details', style: TextStyle(color: Color(0xFF5E6FFF), fontWeight: FontWeight.w600))),
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

class _BatteryCell extends StatelessWidget {
  const _BatteryCell({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 60
        ? const Color(0xFF00CFA0)
        : percent >= 30
            ? const Color(0xFFE4A100)
            : const Color(0xFFE14A5B);

    return Row(
      children: [
        Icon(Icons.battery_4_bar, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LinkCell extends StatelessWidget {
  const _LinkCell({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 70
        ? const Color(0xFF00CFA0)
        : percent >= 40
            ? const Color(0xFFE4A100)
            : const Color(0xFFE14A5B);

    return Row(
      children: [
        Icon(Icons.signal_cellular_alt, size: 16, color: color),
        const SizedBox(width: 8),
        Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MissionBadge extends StatelessWidget {
  const _MissionBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      'Active' => (const Color(0x1A00CFA0), const Color(0xFF00CFA0)),
      'Returning' => (const Color(0x1A4092FF), const Color(0xFF4092FF)),
      'Idle' => (const Color(0x1A7D8DB4), const Color(0xFF9DA9C7)),
      _ => (const Color(0x1AE4A100), const Color(0xFFE4A100)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(state, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _AgentRow {
  const _AgentRow(this.callsign, this.battery, this.link, this.state, this.lastTelemetry);

  final String callsign;
  final int battery;
  final int link;
  final String state;
  final String lastTelemetry;
}
