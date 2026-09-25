import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../models/command.dart';

/// Flight controls backed by durable command acceptance and restored history.
class FlightCommandPanel extends StatefulWidget {
  const FlightCommandPanel({
    super.key,
    required this.api,
    required this.flight,
  });
  final AeroArcApiClient api;
  final FlightRecord flight;
  @override
  State<FlightCommandPanel> createState() => _FlightCommandPanelState();
}

class _FlightCommandPanelState extends State<FlightCommandPanel> {
  List<FlightCommand> _commands = [];
  Timer? _timer;
  String? _error, _pendingType, _pendingKey;
  bool _loading = true,
      _sending = false,
      _refreshing = false,
      _historyAvailable = false;
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing || !widget.api.hasLocalMissionControlToken) {
      if (mounted && _loading) setState(() => _loading = false);
      return;
    }
    _refreshing = true;
    try {
      final commands = await widget.api.flightCommands(widget.flight.id);
      if (mounted) {
        setState(() {
          _commands = commands;
          _loading = false;
          _historyAvailable = true;
          if (_error?.startsWith('Command history unavailable:') ?? false) {
            _error = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Command history unavailable: $e';
          _historyAvailable = false;
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _submit(String type) async {
    if (_sending) return;
    if (_pendingKey == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Issue ${type.replaceAll('_', ' ')}?'),
          content: Text(
            'Aircraft ${widget.flight.aircraftId}\nFlight ${widget.flight.id}\n\n'
            'This requests an aircraft action. Acceptance records the request; execution and observation are reported separately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Issue command'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final random = Random.secure();
      _pendingKey = List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      _pendingType = type;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final command = await widget.api.submitFlightCommand(
        flightId: widget.flight.id,
        type: _pendingType!,
        idempotencyKey: _pendingKey!,
      );
      if (!mounted) return;
      setState(() {
        _commands = [command, ..._commands.where((c) => c.id != command.id)];
        _pendingKey = null;
        _pendingType = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Submission outcome not confirmed: $e. Retry uses the same request identity.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        _loading ||
        !_historyAvailable ||
        _sending ||
        _pendingKey != null ||
        _commands.any((c) => c.unresolved);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aircraft commands',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Accepted → acknowledged → applied. Vehicle observation is recorded separately.',
            ),
            if (!widget.api.hasLocalMissionControlToken)
              const Text(
                'Configure the trusted local control session to issue commands.',
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in [
                  'ARM',
                  'DISARM',
                  'MISSION_START',
                  'PAUSE',
                  'RESUME',
                  'RTL',
                  'LAND',
                ])
                  OutlinedButton(
                    onPressed:
                        blocked || !widget.api.hasLocalMissionControlToken
                        ? null
                        : () => _submit(type),
                    child: Text(type.replaceAll('_', ' ')),
                  ),
              ],
            ),
            if (_pendingKey != null)
              TextButton(
                onPressed: _sending ? null : () => _submit(_pendingType!),
                child: const Text('Retry same request'),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                const Expanded(child: Text('Command history')),
                IconButton(
                  tooltip: 'Refresh command history',
                  onPressed: () => unawaited(_refresh()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!_loading && _commands.isEmpty)
              const Text('No accepted commands for this flight.'),
            for (final command in _commands)
              ExpansionTile(
                key: ValueKey(command.id),
                title: Text(
                  '${command.type.replaceAll('_', ' ')} · ${command.state.replaceAll('_', ' ')}',
                ),
                subtitle: Text(
                  'Observation: ${command.observationState} · ${command.attempts} delivery attempts',
                ),
                children: [
                  SelectableText(command.id),
                  if (command.unresolved ||
                      (command.state == 'applied' &&
                          command.observationState == 'pending'))
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () async {
                              setState(() => _sending = true);
                              try {
                                await widget.api.reconcileFlightCommand(
                                  widget.flight.id,
                                  command.id,
                                );
                                await _refresh();
                              } catch (e) {
                                if (mounted) {
                                  setState(
                                    () => _error =
                                        'Evidence recovery unavailable: $e',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _sending = false);
                              }
                            },
                      child: const Text('Reconcile existing command'),
                    ),

                  for (final event in command.events)
                    ListTile(
                      dense: true,
                      title: Text(
                        '${event.stage.replaceAll('_', ' ')} · ${event.occurredAt.toLocal()}',
                      ),
                      subtitle: Text(
                        '${event.message}\nSource: ${event.source} · Received: ${event.receivedAt.toLocal()}',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
