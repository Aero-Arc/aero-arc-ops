import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Aligned, selectable evidence value with an explicit full-value copy action.
class ConformanceEvidenceField extends StatelessWidget {
  const ConformanceEvidenceField({
    super.key,
    required this.label,
    required this.value,
  });
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF24313E))),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
        );
        final valueWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFFD3DDE7),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_outlined, size: 15),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 6), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 136,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: labelWidget,
              ),
            ),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}
