import 'package:flutter/material.dart';

class RelaysPage extends StatelessWidget {
  const RelaysPage({super.key});

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
              'Relays',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage and monitor relay infrastructure',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  final cardWidth = (constraints.maxWidth - 36) / 4;
                  return Row(
                    children: [
                      _MetricCard(width: cardWidth, label: 'Total Relays', value: '12'),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Healthy',
                        value: '10',
                        valueColor: const Color(0xFF00CFA0),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Degraded',
                        value: '1',
                        valueColor: const Color(0xFFE4A100),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        label: 'Offline',
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
                    _MetricCard(label: 'Total Relays', value: '12'),
                    _MetricCard(label: 'Healthy', value: '10', valueColor: Color(0xFF00CFA0)),
                    _MetricCard(label: 'Degraded', value: '1', valueColor: Color(0xFFE4A100)),
                    _MetricCard(label: 'Offline', value: '1', valueColor: Color(0xFFE14A5B)),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _RelayStatusPanel()),
                      SizedBox(width: 18),
                      Expanded(flex: 3, child: _RelayDetailsPanel()),
                    ],
                  );
                }

                return const Column(
                  children: [
                    _RelayStatusPanel(),
                    SizedBox(height: 18),
                    _RelayDetailsPanel(),
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

class _RelayStatusPanel extends StatelessWidget {
  const _RelayStatusPanel();

  static const _rows = [
    _RelayRow('relay-us-west-2a', 'Healthy', 24, 'us-west-2a', '1.2k/s', '2s ago'),
    _RelayRow('relay-us-east-1b', 'Healthy', 18, 'us-east-1b', '980/s', '1s ago'),
    _RelayRow('relay-eu-central-1', 'Degraded', 12, 'eu-central-1', '450/s', '5s ago'),
    _RelayRow('relay-ap-south-1a', 'Healthy', 16, 'ap-south-1a', '720/s', '1s ago'),
    _RelayRow('relay-us-west-1c', 'Healthy', 21, 'us-west-1c', '1.1k/s', '2s ago'),
    _RelayRow('relay-eu-west-2b', 'Offline', 0, 'eu-west-2b', '0/s', '5m ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Relay Status',
      child: Padding(
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
            columnSpacing: 28,
            dividerThickness: 1,
            headingRowColor: WidgetStatePropertyAll(const Color(0xFF0A1531)),
            dataRowColor: WidgetStatePropertyAll(const Color(0xFF0A1531)),
            columns: const [
              DataColumn(label: Text('Relay ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Nodes')),
              DataColumn(label: Text('Region')),
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Heartbeat')),
              DataColumn(label: SizedBox(width: 16)),
            ],
            rows: [
              for (final row in _rows)
                DataRow(
                  cells: [
                    DataCell(Text(row.id, style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(_StatusBadge(status: row.status)),
                    DataCell(Text('${row.nodes}')),
                    DataCell(Text(row.region)),
                    DataCell(Text(row.rate)),
                    DataCell(Text(row.heartbeat)),
                    const DataCell(Icon(Icons.chevron_right, color: Color(0xFF5E6FFF), size: 18)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelayDetailsPanel extends StatelessWidget {
  const _RelayDetailsPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Relay Details',
      child: SizedBox(
        height: 266,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.settings_input_antenna, size: 58, color: Color(0xFF4A54E0)),
              SizedBox(height: 14),
              Text('Select a relay to view details', style: TextStyle(color: Color(0xFF7D8DB4), fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Healthy' => const Color(0xFF00CFA0),
      'Degraded' => const Color(0xFFE4A100),
      _ => const Color(0xFFE14A5B),
    };

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

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

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
          child,
        ],
      ),
    );
  }
}

class _RelayRow {
  const _RelayRow(this.id, this.status, this.nodes, this.region, this.rate, this.heartbeat);

  final String id;
  final String status;
  final int nodes;
  final String region;
  final String rate;
  final String heartbeat;
}
