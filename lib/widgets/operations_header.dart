import 'dart:async';

import 'package:flutter/material.dart';

/// Shared operator header. Environment and identity are never inferred.
class OperationsHeader extends StatefulWidget {
  const OperationsHeader({super.key});

  @override
  State<OperationsHeader> createState() => _OperationsHeaderState();
}

class _OperationsHeaderState extends State<OperationsHeader> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Color(0xFF0B1016),
      border: Border(bottom: BorderSide(color: Color(0xFF202C39))),
    ),
    child: LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aero Arc Operations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE5EBF2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  box.maxWidth > 1050
                      ? 'Live operational state across missions, aircraft, airspace, and infrastructure.'
                      : 'Live fleet & mission workspace',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8797AB),
                  ),
                ),
              ],
            ),
          ),
          if (box.maxWidth > 850) ...[
            const Tooltip(
              message:
                  'Environment label supplied at build time with AERO_ARC_ENVIRONMENT',
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.dns_outlined, size: 14),
                label: Text(
                  String.fromEnvironment(
                    'AERO_ARC_ENVIRONMENT',
                    defaultValue: 'Local',
                  ),
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Tooltip(
            message: 'Platform health feed is not configured',
            child: Text(
              '● Status unknown',
              style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_time(_now.toUtc())} UTC',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                '${_time(_now)} ${_now.timeZoneName}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8797AB)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
