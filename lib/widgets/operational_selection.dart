import 'package:flutter/material.dart';

import '../models/aero_arc_models.dart';

/// Shared focus is identity only; it never grants command or flight authority.
class OperationalSelection extends ChangeNotifier {
  String? aircraftId;
  String? intentId;
  final Map<String, OperationalIntent> _intents = {};

  OperationalIntent? intent(String? id) => _intents[id];

  void remember(Iterable<OperationalIntent> intents) {
    for (final intent in intents) {
      _intents[intent.id] = intent;
    }
  }

  void select(String aircraft, {String? intent}) {
    if (aircraftId == aircraft && intentId == intent) return;
    aircraftId = aircraft;
    intentId = intent;
    notifyListeners();
  }

  void clear() {
    if (aircraftId == null && intentId == null) return;
    aircraftId = null;
    intentId = null;
    notifyListeners();
  }
}

class OperationalSelectionScope
    extends InheritedNotifier<OperationalSelection> {
  const OperationalSelectionScope({
    super.key,
    required OperationalSelection selection,
    required super.child,
  }) : super(notifier: selection);

  static OperationalSelection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OperationalSelectionScope>()
      ?.notifier;
}

String shortOperationalId(String id) =>
    id.length > 14 ? '${id.substring(0, 8)}…' : id;

String operationName(BuildContext context, String intentId, String aircraftId) {
  final intent = OperationalSelectionScope.maybeOf(context)?.intent(intentId);
  return intent?.name.trim().isNotEmpty == true
      ? intent!.name
      : '$aircraftId operation';
}

void focusOperation(
  BuildContext context,
  String aircraftId, {
  String? intentId,
  bool closeDialog = false,
}) {
  OperationalSelectionScope.maybeOf(
    context,
  )?.select(aircraftId, intent: intentId);
  final navigator = Navigator.of(context);
  if (closeDialog) navigator.pop();
  navigator.pushNamed('/overview');
}

class OperationalSelectionHost extends StatefulWidget {
  const OperationalSelectionHost({super.key, required this.child});
  final Widget child;
  @override
  State<OperationalSelectionHost> createState() =>
      _OperationalSelectionHostState();
}

class _OperationalSelectionHostState extends State<OperationalSelectionHost> {
  final selection = OperationalSelection();
  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      OperationalSelectionScope(selection: selection, child: widget.child);
}
