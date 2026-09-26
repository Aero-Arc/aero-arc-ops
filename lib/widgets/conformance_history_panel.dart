import 'dart:async';

import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../models/conformance_history.dart';
import 'dashboard_ui.dart';
import 'conformance_event_dialog.dart';
import 'operational_selection.dart';

/// Reads persisted transitions independently of live-summary availability.
class ConformanceHistoryPanel extends StatefulWidget {
  const ConformanceHistoryPanel({
    super.key,
    required this.api,
    required this.summaries,
  });
  final AeroArcApiClient api;
  final List<ConformanceSummary> summaries;
  @override
  State<ConformanceHistoryPanel> createState() =>
      _ConformanceHistoryPanelState();
}

class _ConformanceHistoryPanelState extends State<ConformanceHistoryPanel> {
  Timer? _timer;
  String? _intent;
  bool _currentGeneration = false;
  Duration? _window;
  DateTime? _from;
  int _request = 0;
  bool _busy = false, _paged = false, _loaded = false;
  bool _retainedScope = false;
  String? _error, _next;
  List<ConformanceHistoryEvent> _events = [];

  Map<String, ConformanceSummary> get _scopes => {
    for (final s in widget.summaries) s.intentId: s,
  };
  int get _generation =>
      _currentGeneration ? _scopes[_intent]?.assignmentGeneration ?? 0 : 0;

  @override
  void initState() {
    super.initState();
    _intent = _scopes.keys.firstOrNull;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_busy && !_paged) _load(background: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selected = OperationalSelectionScope.maybeOf(context)?.intentId;
    if (selected != null &&
        selected != _intent &&
        _scopes.containsKey(selected)) {
      _intent = selected;
      _reset();
    }
  }

  @override
  void didUpdateWidget(covariant ConformanceHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scopes.containsKey(_intent)) {
      _intent = _scopes.keys.firstOrNull;
      _reset();
    } else if (_currentGeneration) {
      final previous = oldWidget.summaries
          .where((s) => s.intentId == _intent)
          .firstOrNull;
      if (previous?.assignmentGeneration !=
          _scopes[_intent]?.assignmentGeneration) {
        _reset(retainEvents: true);
      }
    }
  }

  void _reset({bool retainEvents = false}) {
    _request++;
    _retainedScope = retainEvents && _loaded;
    if (!_retainedScope) {
      _events = [];
      _loaded = false;
    }
    _next = null;
    _paged = false;
    _busy = false;
    _error = null;
    _from = _window == null ? null : DateTime.now().toUtc().subtract(_window!);
    _load();
  }

  Future<void> _load({bool more = false, bool background = false}) async {
    final intent = _intent;
    if (intent == null || _busy) return;
    final request = ++_request;
    _busy = true;
    if (more) _paged = true;
    if (!background) setState(() => _error = null);
    try {
      final page = await widget.api.conformanceHistory(
        intent,
        generation: _generation,
        from: _from,
        pageToken: more ? _next : null,
      );
      if (!mounted || request != _request) return;
      setState(() {
        // Stable IDs prevent duplicates if a caller refreshes during navigation.
        _events = {
          for (final e in [
            ...(more ? _events : <ConformanceHistoryEvent>[]),
            ...page.events,
          ])
            e.id: e,
        }.values.toList();
        _next = page.nextPageToken;
        _loaded = true;
        _retainedScope = false;
        _paged = more;
        _error = null;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopes = _scopes;
    return Panel(
      title: 'Deviation Timeline',
      trailing: IconButton(
        tooltip: 'Refresh history',
        onPressed: _busy ? null : () => _load(),
        icon: const Icon(Icons.refresh, size: 18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recorded incident transitions · newest first',
              style: TextStyle(color: Color(0xFF8797AB), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (scopes.isNotEmpty)
              DropdownButtonFormField<String>(
                key: ValueKey(_intent),
                initialValue: _intent,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Operation',
                  isDense: true,
                ),
                items: [
                  for (final s in scopes.values)
                    DropdownMenuItem(
                      value: s.intentId,
                      child: Text(
                        '${operationName(context, s.intentId, s.aircraftId)} · ${shortOperationalId(s.intentId)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null && value != _intent) {
                    setState(() {
                      _intent = value;
                      final summary = _scopes[value];
                      if (summary != null) {
                        OperationalSelectionScope.maybeOf(
                          context,
                        )?.select(summary.aircraftId, intent: value);
                      }
                      _reset();
                    });
                  }
                },
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('All generations'),
                  selected: !_currentGeneration,
                  onSelected: (_) {
                    if (!_currentGeneration) return;
                    setState(() {
                      _currentGeneration = false;
                      _reset(retainEvents: true);
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Current generation'),
                  selected: _currentGeneration,
                  onSelected: _scopes[_intent]?.assignmentGeneration == null
                      ? null
                      : (_) {
                          if (_currentGeneration) return;
                          setState(() {
                            _currentGeneration = true;
                            _reset(retainEvents: true);
                          });
                        },
                ),
                PopupMenuButton<Duration>(
                  tooltip: 'History time range',
                  onSelected: (value) {
                    final window = value == Duration.zero ? null : value;
                    if (window == _window) return;
                    setState(() {
                      _window = window;
                      _reset(retainEvents: true);
                    });
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: Duration.zero,
                      child: Text('All recorded history'),
                    ),
                    PopupMenuItem(
                      value: Duration(hours: 1),
                      child: Text('Last hour'),
                    ),
                    PopupMenuItem(
                      value: Duration(hours: 24),
                      child: Text('Last 24 hours'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _window == null
                          ? 'All time ▾'
                          : _window!.inHours == 1
                          ? 'Last hour ▾'
                          : 'Last 24 hours ▾',
                    ),
                  ),
                ),
              ],
            ),
            if (_paged)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Browsing older events · refresh to see new transitions',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8797AB)),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'History unavailable',
                      style: TextStyle(color: Color(0xFFE4A100)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _retainedScope
                          ? 'Selected history could not be loaded. Events below use the previous filter.'
                          : _loaded
                          ? 'Previously loaded events remain below. Live monitoring is separate.'
                          : 'Live monitoring may still be current. No history could be loaded.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _load(more: _paged && _next != null),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry history'),
                    ),
                  ],
                ),
              ),
            if (_busy && !_loaded)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('Loading recorded history…'),
              ),
            if (_intent == null)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No operation is available to inspect.'),
              ),
            if (_loaded && _events.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _retainedScope
                      ? 'No recorded transitions in the previous filter. Awaiting selected history.'
                      : 'No recorded transitions in this scope. This does not imply current conformance.',
                ),
              ),
            if (_events.isNotEmpty)
              SizedBox(
                height: 360,
                child: ListView.separated(
                  itemCount: _events.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = _events[index];
                    final resolved = e.transition == 'resolved';
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 5),
                        leading: Icon(
                          resolved
                              ? Icons.check_circle_outline
                              : Icons.warning_amber,
                          color: resolved
                              ? const Color(0xFF21C997)
                              : const Color(0xFFE4A100),
                          size: 18,
                        ),
                        title: Text(
                          '${displayEnum(e.violationType)} · ${displayEnum(e.transition)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${_utc(e.observedAt)} · generation ${e.generation}\n${e.measurementLabel}${e.isTemporal || e.deviationM == null ? '' : ' at transition'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8797AB),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => _details(context, e),
                      ),
                    );
                  },
                ),
              ),
            if (_next?.isNotEmpty == true)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _load(more: true),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load older events'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _utc(DateTime value) => '${formatDate(value, utc: true)} UTC';

void _details(BuildContext context, ConformanceHistoryEvent e) {
  OperationalSelectionScope.maybeOf(
    context,
  )?.select(e.aircraftId, intent: e.intentId);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => ConformanceEventDialog(event: e),
  );
}
