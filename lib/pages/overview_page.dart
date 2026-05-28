import 'package:flutter/material.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
              'System Overview',
              style: textTheme.headlineMedium?.copyWith(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time infrastructure monitoring and status',
              style: textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF7F90B6),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 36) / 4;
                if (constraints.maxWidth >= 1100) {
                  return Row(
                    children: [
                      _StatCard(
                        width: cardWidth,
                        title: 'System Status',
                        value: 'Operational',
                        subtitle: 'All services running',
                        accent: const Color(0xFF6C75FF),
                        icon: Icons.graphic_eq,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        width: cardWidth,
                        title: 'Active Relays',
                        value: '12',
                        subtitle: '+2 from last hour',
                        subtitleColor: const Color(0xFF00CFA0),
                        accent: const Color(0xFF6C75FF),
                        icon: Icons.settings_input_antenna,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        width: cardWidth,
                        title: 'Online Drones',
                        value: '48',
                        subtitle: '3 in mission',
                        accent: const Color(0xFF6C75FF),
                        icon: Icons.flight,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        width: cardWidth,
                        title: 'Registry Entries',
                        value: '156',
                        subtitle: 'All TTLs healthy',
                        accent: const Color(0xFF6C75FF),
                        icon: Icons.storage,
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _StatCard(
                      title: 'System Status',
                      value: 'Operational',
                      subtitle: 'All services running',
                      icon: Icons.graphic_eq,
                    ),
                    _StatCard(
                      title: 'Active Relays',
                      value: '12',
                      subtitle: '+2 from last hour',
                      subtitleColor: Color(0xFF00CFA0),
                      icon: Icons.settings_input_antenna,
                    ),
                    _StatCard(
                      title: 'Online Drones',
                      value: '48',
                      subtitle: '3 in mission',
                      icon: Icons.flight,
                    ),
                    _StatCard(
                      title: 'Registry Entries',
                      value: '156',
                      subtitle: 'All TTLs healthy',
                      icon: Icons.storage,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(
                        child: _ChartCard(
                          title: 'Average Latency (ms)',
                          maxY: 60,
                          points: [42, 38, 45, 53, 49, 41, 39],
                          lineColor: Color(0xFF6770FF),
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: _ChartCard(
                          title: 'Message Throughput',
                          maxY: 2600,
                          points: [1200, 980, 2100, 2450, 2250, 1900, 1400],
                          lineColor: Color(0xFF00CFA0),
                          fillArea: true,
                        ),
                      ),
                    ],
                  );
                }

                return const Column(
                  children: [
                    _ChartCard(
                      title: 'Average Latency (ms)',
                      maxY: 60,
                      points: [42, 38, 45, 53, 49, 41, 39],
                      lineColor: Color(0xFF6770FF),
                    ),
                    SizedBox(height: 18),
                    _ChartCard(
                      title: 'Message Throughput',
                      maxY: 2600,
                      points: [1200, 980, 2100, 2450, 2250, 1900, 1400],
                      lineColor: Color(0xFF00CFA0),
                      fillArea: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: _HeartbeatCard()),
                      SizedBox(width: 18),
                      Expanded(child: _EventsCard()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    _HeartbeatCard(),
                    SizedBox(height: 18),
                    _EventsCard(),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 33),
            ),
          ),
          Container(height: 1, color: const Color(0xFF10254D)),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.subtitleColor,
    this.accent = const Color(0xFF6770FF),
    this.width,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? subtitleColor;
  final Color accent;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 130, minWidth: 210),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1531),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF12305F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 14),
              ),
              const Spacer(),
              Icon(icon, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 44),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: subtitleColor ?? const Color(0xFF7F90B6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.maxY,
    required this.points,
    required this.lineColor,
    this.fillArea = false,
  });

  final String title;
  final double maxY;
  final List<double> points;
  final Color lineColor;
  final bool fillArea;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: AspectRatio(
          aspectRatio: 1.85,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              maxY: maxY,
              lineColor: lineColor,
              fillArea: fillArea,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartbeatCard extends StatelessWidget {
  const _HeartbeatCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Node Heartbeats',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in [0.78, 0.81, 0.84, 0.83, 0.85, 0.82, 0.86])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Container(
                      height: 160 * value,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF4A54E0), Color(0xFF6871FF)],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Relay us-west-2a connected successfully', '2m ago'),
      ('Node eu-central-1 heartbeat restored', '5m ago'),
      ('Telemetry aggregator scaled to 3 replicas', '11m ago'),
      ('Registry entry ttl refresh completed', '17m ago'),
    ];

    return _Panel(
      title: 'Recent Events',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final row in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF101C3B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF183664)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF4092FF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1,
                            style: const TextStyle(
                              color: Color(0xFFC3CDE8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.$2,
                            style: const TextStyle(
                              color: Color(0xFF7D8DB4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
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

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.maxY,
    required this.lineColor,
    required this.fillArea,
  });

  final List<double> points;
  final double maxY;
  final Color lineColor;
  final bool fillArea;

  @override
  void paint(Canvas canvas, Size size) {
    const marginLeft = 58.0;
    const marginBottom = 28.0;
    const marginTop = 12.0;
    const marginRight = 8.0;

    final chart = Rect.fromLTWH(
      marginLeft,
      marginTop,
      size.width - marginLeft - marginRight,
      size.height - marginTop - marginBottom,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF122B54)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    for (var i = 0; i <= 6; i++) {
      final x = chart.left + (chart.width * i / 6);
      canvas.drawLine(
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        gridPaint..color = const Color(0xFF0F2347),
      );
    }

    final axisPaint = Paint()
      ..color = const Color(0xFF3A537F)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(chart.left, chart.top),
      Offset(chart.left, chart.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );

    final path = Path();
    final pointOffsets = <Offset>[];

    for (var i = 0; i < points.length; i++) {
      final x = chart.left + (chart.width * i / (points.length - 1));
      final y = chart.bottom - (chart.height * (points[i] / maxY));
      pointOffsets.add(Offset(x, y));
    }

    for (var i = 0; i < pointOffsets.length; i++) {
      if (i == 0) {
        path.moveTo(pointOffsets[i].dx, pointOffsets[i].dy);
      } else {
        final prev = pointOffsets[i - 1];
        final cur = pointOffsets[i];
        final c1 = Offset((prev.dx + cur.dx) / 2, prev.dy);
        final c2 = Offset((prev.dx + cur.dx) / 2, cur.dy);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cur.dx, cur.dy);
      }
    }

    if (fillArea) {
      final fill = Path.from(path)
        ..lineTo(pointOffsets.last.dx, chart.bottom)
        ..lineTo(pointOffsets.first.dx, chart.bottom)
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.35),
              lineColor.withValues(alpha: 0.04),
            ],
          ).createShader(chart),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final dot = Paint()..color = lineColor;
    for (final offset in pointOffsets) {
      canvas.drawCircle(offset, 4.5, dot);
    }

    final yStyle = const TextStyle(color: Color(0xFF6F80A7), fontSize: 11);
    final yLabels = [0, maxY * 0.25, maxY * 0.5, maxY * 0.75, maxY];
    for (var i = 0; i < yLabels.length; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      final label = yLabels[i] % 1 == 0
          ? yLabels[i].toInt().toString()
          : yLabels[i].toStringAsFixed(1);
      _drawText(canvas, label, Offset(4, y - 7), yStyle);
    }

    const xLabels = [
      '00:00',
      '04:00',
      '08:00',
      '12:00',
      '16:00',
      '20:00',
      '24:00',
    ];
    for (var i = 0; i < xLabels.length; i++) {
      final x = chart.left + (chart.width * i / (xLabels.length - 1));
      final tp = TextPainter(
        text: TextSpan(
          text: xLabels[i],
          style: const TextStyle(color: Color(0xFF7788AE), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxY != maxY ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillArea != fillArea;
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }
}
