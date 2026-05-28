import 'dart:math' as math;

import 'package:flutter/material.dart';

class TelemetryPage extends StatelessWidget {
  const TelemetryPage({super.key});

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
              'Telemetry',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 46),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time system metrics and performance monitoring',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  final cardWidth = (constraints.maxWidth - 36) / 4;
                  return Row(
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        title: 'Avg Latency',
                        value: '42ms',
                        subtitle: '-8% from baseline',
                        subtitleColor: const Color(0xFF00CFA0),
                        icon: Icons.south_east,
                        iconColor: const Color(0xFF00CFA0),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Throughput',
                        value: '1.4k/s',
                        subtitle: '+12% from baseline',
                        subtitleColor: const Color(0xFF00CFA0),
                        icon: Icons.north_east,
                        iconColor: const Color(0xFF00CFA0),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Error Rate',
                        value: '0.08%',
                        subtitle: 'Within threshold',
                        subtitleColor: const Color(0xFF8FA0C5),
                        icon: Icons.graphic_eq,
                        iconColor: const Color(0xFF6770FF),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: cardWidth,
                        title: 'Uptime',
                        value: '99.98%',
                        subtitle: 'Last 30 days',
                        subtitleColor: const Color(0xFF00CFA0),
                        icon: Icons.bolt,
                        iconColor: const Color(0xFF00CFA0),
                      ),
                    ],
                  );
                }

                return const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: 'Avg Latency',
                      value: '42ms',
                      subtitle: '-8% from baseline',
                      subtitleColor: Color(0xFF00CFA0),
                      icon: Icons.south_east,
                      iconColor: Color(0xFF00CFA0),
                    ),
                    _MetricCard(
                      title: 'Throughput',
                      value: '1.4k/s',
                      subtitle: '+12% from baseline',
                      subtitleColor: Color(0xFF00CFA0),
                      icon: Icons.north_east,
                      iconColor: Color(0xFF00CFA0),
                    ),
                    _MetricCard(
                      title: 'Error Rate',
                      value: '0.08%',
                      subtitle: 'Within threshold',
                      subtitleColor: Color(0xFF8FA0C5),
                      icon: Icons.graphic_eq,
                      iconColor: Color(0xFF6770FF),
                    ),
                    _MetricCard(
                      title: 'Uptime',
                      value: '99.98%',
                      subtitle: 'Last 30 days',
                      subtitleColor: Color(0xFF00CFA0),
                      icon: Icons.bolt,
                      iconColor: Color(0xFF00CFA0),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1100) {
                  return const Row(
                    children: [
                      Expanded(
                        child: _LinePanel(
                          title: 'Latency Trends',
                          maxY: 60,
                          yLabels: ['0', '15', '30', '45', '60'],
                          points: [42, 38, 45, 53, 49, 41, 39],
                          xLabels: ['19:00', '19:05', '19:10', '19:15', '19:20', '19:25', '19:30'],
                          color: Color(0xFF6770FF),
                        ),
                      ),
                      SizedBox(width: 18),
                      Expanded(
                        child: _LinePanel(
                          title: 'Message Throughput',
                          maxY: 1600,
                          yLabels: ['0', '400', '800', '1200', '1600'],
                          points: [1200, 1350, 1290, 1470, 1530, 1390, 1430],
                          xLabels: ['19:00', '19:05', '19:10', '19:15', '19:20', '19:25', '19:30'],
                          color: Color(0xFF00CFA0),
                          fillArea: true,
                        ),
                      ),
                    ],
                  );
                }

                return const Column(
                  children: [
                    _LinePanel(
                      title: 'Latency Trends',
                      maxY: 60,
                      yLabels: ['0', '15', '30', '45', '60'],
                      points: [42, 38, 45, 53, 49, 41, 39],
                      xLabels: ['19:00', '19:05', '19:10', '19:15', '19:20', '19:25', '19:30'],
                      color: Color(0xFF6770FF),
                    ),
                    SizedBox(height: 18),
                    _LinePanel(
                      title: 'Message Throughput',
                      maxY: 1600,
                      yLabels: ['0', '400', '800', '1200', '1600'],
                      points: [1200, 1350, 1290, 1470, 1530, 1390, 1430],
                      xLabels: ['19:00', '19:05', '19:10', '19:15', '19:20', '19:25', '19:30'],
                      color: Color(0xFF00CFA0),
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
                  return const Row(
                    children: [
                      Expanded(child: _RadarPanel()),
                      SizedBox(width: 18),
                      Expanded(child: _ActivityPanel()),
                    ],
                  );
                }

                return const Column(
                  children: [
                    _RadarPanel(),
                    SizedBox(height: 18),
                    _ActivityPanel(),
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
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.subtitleColor,
    this.width,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color subtitleColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 200, minHeight: 108),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14)),
              const Spacer(),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 39)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
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

class _LinePanel extends StatelessWidget {
  const _LinePanel({
    required this.title,
    required this.maxY,
    required this.yLabels,
    required this.points,
    required this.xLabels,
    required this.color,
    this.fillArea = false,
  });

  final String title;
  final double maxY;
  final List<String> yLabels;
  final List<double> points;
  final List<String> xLabels;
  final Color color;
  final bool fillArea;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: AspectRatio(
          aspectRatio: 1.85,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              maxY: maxY,
              yLabels: yLabels,
              xLabels: xLabels,
              color: color,
              fillArea: fillArea,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPanel extends StatelessWidget {
  const _RadarPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'System Health Score',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: AspectRatio(
          aspectRatio: 1.85,
          child: CustomPaint(
            painter: _RadarPainter(),
          ),
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Agent Fleet Activity',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: AspectRatio(
          aspectRatio: 1.85,
          child: CustomPaint(
            painter: _BarChartPainter(
              values: const [28, 34, 39, 44, 36, 41, 47],
              maxY: 60,
              xLabels: const ['19:00', '19:05', '19:10', '19:15', '19:20', '19:25', '19:30'],
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.maxY,
    required this.yLabels,
    required this.xLabels,
    required this.color,
    required this.fillArea,
  });

  final List<double> points;
  final double maxY;
  final List<String> yLabels;
  final List<String> xLabels;
  final Color color;
  final bool fillArea;

  @override
  void paint(Canvas canvas, Size size) {
    const marginLeft = 56.0;
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
      ..color = const Color(0xFF10254D)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    for (var i = 0; i < xLabels.length; i++) {
      final x = chart.left + (chart.width * i / (xLabels.length - 1));
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint..color = const Color(0xFF0E2146));
    }

    final axisPaint = Paint()
      ..color = const Color(0xFF3A537F)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axisPaint);
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axisPaint);

    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = chart.left + (chart.width * i / (points.length - 1));
      final y = chart.bottom - chart.height * (points[i] / maxY);
      offsets.add(Offset(x, y));
    }

    final path = Path();
    for (var i = 0; i < offsets.length; i++) {
      if (i == 0) {
        path.moveTo(offsets[i].dx, offsets[i].dy);
      } else {
        final prev = offsets[i - 1];
        final cur = offsets[i];
        final cx = (prev.dx + cur.dx) / 2;
        path.cubicTo(cx, prev.dy, cx, cur.dy, cur.dx, cur.dy);
      }
    }

    if (fillArea) {
      final fillPath = Path.from(path)
        ..lineTo(offsets.last.dx, chart.bottom)
        ..lineTo(offsets.first.dx, chart.bottom)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.36), color.withValues(alpha: 0.06)],
          ).createShader(chart),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final dotPaint = Paint()..color = color;
    for (final point in offsets) {
      canvas.drawCircle(point, 4.5, dotPaint);
    }

    for (var i = 0; i < yLabels.length; i++) {
      final y = chart.bottom - (chart.height * i / (yLabels.length - 1));
      _drawText(canvas, yLabels[i], Offset(4, y - 7), const TextStyle(color: Color(0xFF7788AE), fontSize: 11));
    }

    for (var i = 0; i < xLabels.length; i++) {
      final x = chart.left + (chart.width * i / (xLabels.length - 1));
      final tp = TextPainter(
        text: TextSpan(text: xLabels[i], style: const TextStyle(color: Color(0xFF7788AE), fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxY != maxY || oldDelegate.color != color;
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = math.min(size.width, size.height) * 0.34;

    const labels = ['Compute', 'Relay', 'Agents', 'Registry', 'Telemetry'];
    const values = [0.86, 0.78, 0.74, 0.81, 0.89];

    final gridPaint = Paint()
      ..color = const Color(0xFF10254D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < labels.length; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / labels.length);
        final pt = center + Offset(math.cos(angle), math.sin(angle)) * ringRadius;
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / labels.length);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, gridPaint);

      final labelPt = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 16);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: const TextStyle(color: Color(0xFF7D8DB4), fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelPt.dx - tp.width / 2, labelPt.dy - tp.height / 2));
    }

    final valuePath = Path();
    for (var i = 0; i < labels.length; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / labels.length);
      final pt = center + Offset(math.cos(angle), math.sin(angle)) * (radius * values[i]);
      if (i == 0) {
        valuePath.moveTo(pt.dx, pt.dy);
      } else {
        valuePath.lineTo(pt.dx, pt.dy);
      }
    }
    valuePath.close();

    canvas.drawPath(
      valuePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x704A54E0), Color(0x304A54E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      valuePath,
      Paint()
        ..color = const Color(0xFF6770FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.values, required this.maxY, required this.xLabels});

  final List<double> values;
  final double maxY;
  final List<String> xLabels;

  @override
  void paint(Canvas canvas, Size size) {
    const marginLeft = 56.0;
    const marginBottom = 28.0;
    const marginTop = 12.0;
    const marginRight = 8.0;

    final chart = Rect.fromLTWH(
      marginLeft,
      marginTop,
      size.width - marginLeft - marginRight,
      size.height - marginTop - marginBottom,
    );

    final grid = Paint()
      ..color = const Color(0xFF10254D)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    for (var i = 0; i < xLabels.length; i++) {
      final x = chart.left + chart.width * i / (xLabels.length - 1);
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid..color = const Color(0xFF0E2146));
    }

    final axis = Paint()
      ..color = const Color(0xFF3A537F)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axis);
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axis);

    final barWidth = chart.width / (values.length * 1.9);
    for (var i = 0; i < values.length; i++) {
      final xCenter = chart.left + chart.width * i / (values.length - 1);
      final height = chart.height * (values[i] / maxY);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xCenter - barWidth / 2, chart.bottom - height, barWidth, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF4A54E0), Color(0xFF6D75FF)],
          ).createShader(rect.outerRect),
      );
    }

    const yLabels = ['0', '15', '30', '45', '60'];
    for (var i = 0; i < yLabels.length; i++) {
      final y = chart.bottom - (chart.height * i / (yLabels.length - 1));
      _drawText(canvas, yLabels[i], Offset(4, y - 7), const TextStyle(color: Color(0xFF7788AE), fontSize: 11));
    }

    for (var i = 0; i < xLabels.length; i++) {
      final x = chart.left + chart.width * i / (xLabels.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: xLabels[i], style: const TextStyle(color: Color(0xFF7788AE), fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxY != maxY;
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, offset);
  }
}
