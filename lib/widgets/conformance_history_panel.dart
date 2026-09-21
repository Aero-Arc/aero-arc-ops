import 'dart:async';

import 'package:flutter/material.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../models/conformance_history.dart';
import 'dashboard_ui.dart';

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
        _reset();
      }
    }
  }

  void _reset() {
    _request++;
    _events = [];
    _loaded = false;
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
                        '${s.aircraftId} · ${s.intentId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _intent = value;
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
                  onSelected: (_) => setState(() {
                    _currentGeneration = false;
                    _reset();
                  }),
                ),
                ChoiceChip(
                  label: const Text('Current generation'),
                  selected: _currentGeneration,
                  onSelected: _scopes[_intent]?.assignmentGeneration == null
                      ? null
                      : (_) => setState(() {
                          _currentGeneration = true;
                          _reset();
                        }),
                ),
                PopupMenuButton<Duration>(
                  tooltip: 'History time range',
                  onSelected: (value) => setState(() {
                    _window = value == Duration.zero ? null : value;
                    _reset();
                  }),
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
                      _loaded
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No recorded transitions in this scope. This does not imply current conformance.',
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
                          '${_utc(e.observedAt)} · generation ${e.generation}\n${e.deviationM == null ? 'Distance not recorded' : '${e.deviationM!.toStringAsFixed(1)} m at transition'}',
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

String _utc(DateTime value) =>
    '${value.toUtc().toIso8601String().replaceFirst('T', ' ').replaceFirst('Z', '')} UTC';

void _details(
  BuildContext context,
  ConformanceHistoryEvent e,
) => showDetailsSheet(
  context,
  title: '${displayEnum(e.violationType)} · ${displayEnum(e.transition)}',
  children: [
    DetailLine(label: 'Recorded transition', value: _utc(e.observedAt)),
    DetailLine(
      label: 'Distance at transition',
      value: e.deviationM == null ? 'Not recorded' : '${e.deviationM} m',
    ),
    DetailLine(label: 'Aircraft', value: e.aircraftId),
    DetailLine(label: 'Intent', value: '${e.intentId} v${e.intentVersion}'),
    DetailLine(label: 'Assignment generation', value: '${e.generation}'),
    DetailLine(label: 'Flight', value: e.flightId),
    DetailLine(
      label: 'Incident ID',
      value: e.incidentId.isEmpty ? 'Not recorded' : e.incidentId,
    ),
    DetailLine(label: 'Event ID', value: e.id),
    DetailLine(label: 'Evaluation revision', value: '${e.revision}'),
    DetailLine(label: 'Evidence frame', value: e.frameId),
    const Text(
      'Historical evidence does not describe the aircraft’s current condition.',
    ),
    TextButton.icon(
      onPressed: () {
        Navigator.of(context)
          ..pop()
          ..pushNamed('/aircraft/${Uri.encodeComponent(e.aircraftId)}/map');
      },
      icon: const Icon(Icons.map_outlined),
      label: const Text('View aircraft map'),
    ),
  ],
);
