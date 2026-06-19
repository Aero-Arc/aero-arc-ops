import 'package:flutter/material.dart';

import '../models/aero_arc_models.dart';

const aeroPageGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF030B1F), Color(0xFF020815)],
);

class DashboardPage<T> extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.load,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  State<DashboardPage<T>> createState() => _DashboardPageState<T>();
}

class _DashboardPageState<T> extends State<DashboardPage<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _refresh() {
    setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: aeroPageGradient),
      child: FutureBuilder<T>(
        future: _future,
        builder: (context, snapshot) {
          final children = <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 46),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF7F90B6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ];

          if (snapshot.connectionState == ConnectionState.waiting) {
            children.add(const LoadingPanel());
          } else if (snapshot.hasError) {
            children.add(
              ErrorPanel(error: snapshot.error.toString(), onRetry: _refresh),
            );
          } else if (snapshot.hasData) {
            children.addAll(widget.builder(context, snapshot.data as T));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          );
        },
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Panel(
      title: 'Loading',
      child: Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(minHeight: 4),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'API unavailable',
      trailing: IconButton.filledTonal(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(error, style: const TextStyle(color: Color(0xFFE4A100))),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'No data',
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message, style: const TextStyle(color: Color(0xFF93A3C7))),
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const EmptyPanel(message: 'No dashboard metrics are available.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? metrics.length.clamp(1, 5)
            : constraints.maxWidth >= 840
            ? 2
            : 1;
        final spacing = 12.0 * (columns - 1);
        final width = columns == 1
            ? null
            : (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(metric.status ?? metric.value);
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1531),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF12305F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 14),
                ),
              ),
              Icon(Icons.analytics_outlined, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 34, color: color),
          ),
          if (metric.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.detail!,
              style: const TextStyle(color: Color(0xFF8FA0C5), fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08142F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF112855)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 26),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF10254D)),
          child,
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: child),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF6B75FF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDetailsSheet(
  BuildContext context, {
  required String title,
  Widget? status,
  required List<Widget> children,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF07132E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.38,
        maxChildSize: 0.94,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: ListView(
              controller: controller,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFD6E0FF),
                        ),
                      ),
                    ),
                    Visibility(
                      visible: status != null,
                      child: const SizedBox(width: 12),
                    ),
                    ?status,
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFF142B55)),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          );
        },
      );
    },
  );
}

Widget detailSection(String title, List<Widget> children) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Panel(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(children: children),
      ),
    ),
  );
}

String yesNo(bool value) => value ? 'Yes' : 'No';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 8 : 14, color: color),
          const SizedBox(width: 7),
          Text(
            displayEnum(label),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class TwoColumn extends StatelessWidget {
  const TwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 1100,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 18),
              Expanded(child: right),
            ],
          );
        }
        return Column(children: [left, const SizedBox(height: 18), right]);
      },
    );
  }
}

class DetailLine extends StatelessWidget {
  const DetailLine({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF7D8DB4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(color: Color(0xFFC4D0EE), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RowList extends StatelessWidget {
  const RowList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No records available.',
          style: TextStyle(color: Color(0xFF93A3C7)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 24, color: Color(0xFF142B55)),
          ],
        ],
      ),
    );
  }
}

String displayEnum(String value) {
  if (value.isEmpty) {
    return 'Unknown';
  }
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String formatDate(DateTime? value) {
  if (value == null) {
    return 'Not provided';
  }
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String formatPercent(double? value) {
  if (value == null) {
    return 'Not provided';
  }
  final pct = value <= 1 ? value * 100 : value;
  return '${pct.toStringAsFixed(0)}%';
}

String formatMeters(double? value) =>
    value == null ? 'Not provided' : '${value.toStringAsFixed(1)} m';
String formatFeetRange(double? min, double? max) => min == null && max == null
    ? 'Not provided'
    : '${min?.toStringAsFixed(0) ?? '?'}-${max?.toStringAsFixed(0) ?? '?'} ft AGL';

Color statusColor(String status) {
  final normalized = status.toLowerCase().replaceAll(' ', '_');
  return switch (normalized) {
    'ready' ||
    'clear' ||
    'current' ||
    'complete' ||
    'completed' ||
    'healthy' ||
    'accepted' ||
    'active' ||
    'broadcasting' ||
    'conforming' ||
    'exported' ||
    'closed' ||
    'no' => const Color(0xFF00CFA0),
    'review' ||
    'submitted' ||
    'due_soon' ||
    'advisory' ||
    'warning' ||
    'contingent' ||
    'draft' ||
    'open' ||
    'action' => const Color(0xFFE4A100),
    'blocked' ||
    'critical' ||
    'reportable' ||
    'non_conforming' ||
    'overdue' ||
    'emergency' ||
    'offline' ||
    'rejected' ||
    'expired' => const Color(0xFFE14A5B),
    _ => const Color(0xFF6B75FF),
  };
}
