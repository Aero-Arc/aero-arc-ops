import 'package:flutter/material.dart';

import '../models/conformance_history.dart';
import 'dashboard_ui.dart';
import 'conformance_evidence_field.dart';
import 'operational_selection.dart';

/// Focused operational context with optional durable evidence details.
class ConformanceEventDialog extends StatelessWidget {
  const ConformanceEventDialog({super.key, required this.event});

  final ConformanceHistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final resolved = event.transition == 'resolved';
    final opened = event.transition == 'opened';
    final accent = resolved
        ? const Color(0xFF21C997)
        : opened
        ? const Color(0xFFE4A100)
        : const Color(0xFF8797AB);
    final time = event.observedAt.toUtc().toIso8601String();
    final title =
        '${displayEnum(event.violationType)} · ${resolved
            ? 'Resolved'
            : opened
            ? 'Detected'
            : displayEnum(event.transition)}';
    return Dialog(
      backgroundColor: const Color(0xFF101821),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF293847)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      resolved ? Icons.check_circle_outline : Icons.timeline,
                      color: accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'CONFORMANCE EVENT',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.4,
                          color: Color(0xFF8797AB),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close event',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(operationName(context, event.intentId, event.aircraftId)),
                TextButton.icon(
                  onPressed: () => focusOperation(
                    context,
                    event.aircraftId,
                    intentId: event.intentId,
                    closeDialog: true,
                  ),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Focus in Overview'),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE5EDF5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  resolved
                      ? 'The recorded deviation ended at this observation.'
                      : opened
                      ? 'A deviation was recorded for this operation.'
                      : 'A transition was recorded for this operation.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFA0ADBB),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1219),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF293847)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AT THE RECORDED TRANSITION',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: Color(0xFF8797AB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.measurementLabel,
                        style: TextStyle(
                          fontSize: event.isTemporal || event.deviationM == null
                              ? 18
                              : 30,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (event.isTemporal && event.plannedEndAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Planned completion by ${_displayTime(event.plannedEndAt!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA0ADBB),
                            ),
                          ),
                        ),
                      Text(
                        '${time.substring(0, 10)} · ${time.substring(11, 19)} UTC',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA0ADBB),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _EventField(label: 'Aircraft', value: event.aircraftId),
                _EventField(
                  label: 'Flight',
                  value: event.flightId.isEmpty
                      ? 'Not recorded'
                      : event.flightId,
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF293847)),
                ExpansionTile(
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: const Text(
                    'Recorded evidence',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Source identifiers and evaluation context',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
                  ),
                  children: [
                    _EventField(label: 'Event ID', value: event.id),
                    _EventField(
                      label: 'Incident ID',
                      value: event.incidentId.isEmpty
                          ? 'Not recorded'
                          : event.incidentId,
                    ),
                    _EventField(label: 'Operation', value: event.intentId),
                    _EventField(
                      label: 'Intent version',
                      value: '${event.intentVersion}',
                    ),
                    _EventField(label: 'Assignment', value: event.assignmentId),
                    _EventField(
                      label: 'Generation',
                      value: '${event.generation}',
                    ),
                    _EventField(
                      label: 'Evaluation revision',
                      value: '${event.revision}',
                    ),
                    _EventField(label: 'Evidence frame', value: event.frameId),
                    _EventField(label: 'Observation timestamp', value: time),
                    if (!event.isTemporal && event.deviationM != null)
                      _EventField(
                        label: 'Recorded distance (m)',
                        value: '${event.deviationM}',
                      ),
                    if (event.isTemporal && event.plannedStartAt != null)
                      _EventField(
                        label: 'Planned start',
                        value: event.plannedStartAt!.toUtc().toIso8601String(),
                      ),
                    if (event.isTemporal && event.plannedEndAt != null)
                      _EventField(
                        label: 'Planned end',
                        value: event.plannedEndAt!.toUtc().toIso8601String(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Historical evidence—not the aircraft’s current condition.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.pushNamed(
                      '/aircraft/${Uri.encodeComponent(event.aircraftId)}/map',
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 17),
                  label: const Text('View aircraft map'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventField extends StatelessWidget {
  const _EventField({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) =>
      ConformanceEvidenceField(label: label, value: value);
}

String _displayTime(DateTime value) =>
    '${value.toUtc().toIso8601String().substring(0, 19).replaceFirst('T', ' ')} UTC';
