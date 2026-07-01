import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class IntentWorkflowRouteArguments {
  const IntentWorkflowRouteArguments({
    this.initialIntent,
    this.initialVolumes = const [],
    this.initialVolumeCenter,
  });

  final OperationalIntent? initialIntent;
  final List<OperationalVolume> initialVolumes;
  final LatLng? initialVolumeCenter;
}

class IntentWorkflowPage extends StatefulWidget {
  const IntentWorkflowPage({
    super.key,
    required this.aircraftId,
    this.apiClient,
    this.initialIntent,
    this.initialVolumes = const [],
    this.initialVolumeCenter,
  });

  final String aircraftId;
  final AeroArcApiClient? apiClient;
  final OperationalIntent? initialIntent;
  final List<OperationalVolume> initialVolumes;
  final LatLng? initialVolumeCenter;

  @override
  State<IntentWorkflowPage> createState() => _IntentWorkflowPageState();
}

class _IntentWorkflowPageState extends State<IntentWorkflowPage> {
  final _formKey = GlobalKey<FormState>();
  final _missionName = TextEditingController();
  final _summary = TextEditingController();
  final _useCase = TextEditingController(text: 'inspection');
  final _routeSummary = TextEditingController();
  final _supervisorId = TextEditingController();
  final _coordinatorId = TextEditingController();
  final _minAltitudeFt = TextEditingController(text: '100');
  final _maxAltitudeFt = TextEditingController(text: '250');
  final _bufferMeters = TextEditingController(text: '15');

  late final AeroArcApiClient _apiClient;

  bool _conformanceRequired = true;
  bool _busy = false;
  String _authorizationPath = 'demo';
  String _populationCategory = 'cat_1';
  String _altitudeRef = 'agl';
  String _volumeType = 'loiter';
  String _volumeShapeMode = 'box';
  late DateTime _plannedDate;
  late String _plannedStartSlot;
  late String _plannedEndSlot;
  String? _error;
  OperationalIntent? _sourceIntent;
  OperationalIntent? _intent;
  OperationalVolume? _volume;
  ModifyOperationalIntentResult? _modifyResult;
  PreflightEvaluationResult? _preflight;
  DeconflictionResult? _deconfliction;
  OperationalIntent? _acceptedIntent;
  OperationalIntent? _activatedIntent;
  late final LatLng? _initialVolumeCenter;
  late List<LatLng> _volumePoints;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AeroArcApiClient();
    final now = _roundUpToSlot(DateTime.now().add(const Duration(minutes: 15)));
    _plannedDate = DateTime(now.year, now.month, now.day);
    _plannedStartSlot = _slotForTime(now);
    _plannedEndSlot = _slotForTime(now.add(const Duration(hours: 1)));
    _initialVolumeCenter = widget.initialVolumeCenter;
    _volumePoints = _defaultRoutePoints(center: _initialVolumeCenter);
    _sourceIntent = widget.initialIntent;
    _hydrateFromInitialIntent(now);
  }

  @override
  void dispose() {
    _missionName.dispose();
    _summary.dispose();
    _useCase.dispose();
    _routeSummary.dispose();
    _supervisorId.dispose();
    _coordinatorId.dispose();
    _minAltitudeFt.dispose();
    _maxAltitudeFt.dispose();
    _bufferMeters.dispose();
    super.dispose();
  }

  Future<void> _saveAndCheck() async {
    if (!_formKey.currentState!.validate()) return;
    final timeWindowError = _validateTimeWindow();
    if (timeWindowError != null) {
      setState(() => _error = timeWindowError);
      return;
    }
    if (_volumePoints.length < 2) {
      setState(() => _error = 'Add at least two route points on the map.');
      return;
    }
    final volumePolygon = _derivedVolumePolygon();
    if (volumePolygon.length < 3) {
      setState(() => _error = 'Route points could not create a valid volume.');
      return;
    }
    await _runWorkflowAction(() async {
      var intent = _intent;
      var volume = _volume;
      final source = _sourceIntent;
      if (intent != null && intent.status != 'active') {
        final modified = await _apiClient.modifyOperationalIntent(
          intent.id,
          _modifyRequest(intent),
        );
        intent = modified.intent;
        volume = modified.volumes.isEmpty ? null : modified.volumes.first;
        if (!mounted) return;
        setState(() {
          _intent = intent;
          _volume = volume;
          _modifyResult = modified;
        });
      } else if (intent == null && source != null) {
        final modified = await _apiClient.modifyOperationalIntent(
          source.id,
          _modifyRequest(source),
        );
        intent = modified.intent;
        volume = modified.volumes.isEmpty ? null : modified.volumes.first;
        if (!mounted) return;
        setState(() {
          _intent = intent;
          _volume = volume;
          _modifyResult = modified;
        });
      } else {
        if (intent == null) {
          intent = await _apiClient.createOperationalIntent(_intentRequest());
          if (!mounted) return;
          setState(() => _intent = intent);
        }
        if (volume == null) {
          volume = await _apiClient.addOperationalIntentVolume(
            intent.id,
            _volumeRequest(),
          );
          if (!mounted) return;
          setState(() => _volume = volume);
        }
      }
      final submitted = intent.status == 'draft'
          ? await _apiClient.submitOperationalIntent(intent.id)
          : intent;
      if (!mounted) return;
      setState(() => _intent = submitted);
      final preflight = await _apiClient.evaluateOperationalIntentPreflight(
        submitted.id,
      );
      if (!mounted) return;
      setState(() => _preflight = preflight);
      final deconfliction = await _apiClient
          .checkOperationalIntentDeconfliction(submitted.id);
      setState(() {
        _intent = submitted;
        _volume = volume;
        _preflight = preflight;
        _deconfliction = deconfliction;
        _acceptedIntent = null;
        _activatedIntent = null;
      });
    });
  }

  Future<void> _acceptIntent() async {
    final intent = _intent;
    if (intent == null) return;
    await _runWorkflowAction(() async {
      final accepted = await _apiClient.acceptOperationalIntent(intent.id);
      setState(() {
        _intent = accepted;
        _acceptedIntent = accepted;
      });
    });
  }

  Future<void> _activateIntent() async {
    final intent = _acceptedIntent ?? _intent;
    if (intent == null) return;
    await _runWorkflowAction(() async {
      final activated = await _apiClient.activateOperationalIntent(intent.id);
      setState(() {
        _intent = activated;
        _activatedIntent = activated;
      });
    });
  }

  Future<void> _runWorkflowAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  CreateOperationalIntentRequest _intentRequest() {
    return CreateOperationalIntentRequest(
      aircraftId: widget.aircraftId,
      name: _missionName.text.trim(),
      summary: _summary.text.trim(),
      useCase: _emptyToNull(_useCase.text),
      authorizationPath: _authorizationPath,
      populationCategory: _populationCategory,
      conformanceRequired: _conformanceRequired,
      routeSummary: _emptyToNull(_routeSummary.text),
      plannedStartAt: _plannedStartAt(),
      plannedEndAt: _plannedEndAt(),
      minAltitudeFtAgl: double.parse(_minAltitudeFt.text.trim()),
      maxAltitudeFtAgl: double.parse(_maxAltitudeFt.text.trim()),
      supervisorId: _emptyToNull(_supervisorId.text),
      flightCoordinatorId: _emptyToNull(_coordinatorId.text),
    );
  }

  AddOperationalVolumeRequest _volumeRequest() {
    final minFt = double.parse(_minAltitudeFt.text.trim());
    final maxFt = double.parse(_maxAltitudeFt.text.trim());
    return AddOperationalVolumeRequest(
      sequence: 1,
      geoJson: _polygonGeoJson(_derivedVolumePolygon()),
      minAltitudeM: _feetToMeters(minFt),
      maxAltitudeM: _feetToMeters(maxFt),
      altitudeRef: _altitudeRef,
      startsAt: _plannedStartAt(),
      endsAt: _plannedEndAt(),
      bufferMeters: double.tryParse(_bufferMeters.text.trim()),
      volumeType: _volumeType,
    );
  }

  ModifyOperationalIntentRequest _modifyRequest(OperationalIntent source) {
    return ModifyOperationalIntentRequest(
      expectedVersion: source.version,
      intent: ModifyOperationalIntentFields(
        name: _missionName.text.trim(),
        summary: _summary.text.trim(),
        useCase: _emptyToNull(_useCase.text),
        authorizationPath: _authorizationPath,
        populationCategory: _populationCategory,
        conformanceRequired: _conformanceRequired,
        routeSummary: _emptyToNull(_routeSummary.text),
        plannedStartAt: _plannedStartAt(),
        plannedEndAt: _plannedEndAt(),
        minAltitudeFtAgl: double.parse(_minAltitudeFt.text.trim()),
        maxAltitudeFtAgl: double.parse(_maxAltitudeFt.text.trim()),
        supervisorId: _emptyToNull(_supervisorId.text),
        flightCoordinatorId: _emptyToNull(_coordinatorId.text),
      ),
      volumes: [_volumeRequest()],
    );
  }

  void _hydrateFromInitialIntent(DateTime fallbackStart) {
    final intent = widget.initialIntent;
    final firstVolume = widget.initialVolumes.isEmpty
        ? null
        : widget.initialVolumes.first;
    _missionName.text = intent?.name.isNotEmpty == true
        ? intent!.name
        : 'Mission ${widget.aircraftId}';
    _summary.text = intent?.summary.isNotEmpty == true
        ? intent!.summary
        : 'Operational intent for ${widget.aircraftId}';
    _useCase.text = intent?.useCase ?? 'inspection';
    _routeSummary.text = intent?.routeSummary ?? 'Local operational volume';
    _supervisorId.text = intent?.supervisorId ?? '';
    _coordinatorId.text = intent?.flightCoordinatorId ?? '';
    if (intent?.plannedStartAt != null) {
      final plannedStart = intent!.plannedStartAt!.toLocal();
      _plannedDate = DateTime(
        plannedStart.year,
        plannedStart.month,
        plannedStart.day,
      );
      _plannedStartSlot = _slotForTime(plannedStart);
    }
    if (intent?.plannedEndAt != null) {
      _plannedEndSlot = _slotForTime(intent!.plannedEndAt!.toLocal());
    } else if (intent?.plannedStartAt == null) {
      _plannedEndSlot = _slotForTime(
        fallbackStart.add(const Duration(hours: 1)),
      );
    }
    if (intent?.minAltitudeFtAgl != null) {
      _minAltitudeFt.text = intent!.minAltitudeFtAgl!.toStringAsFixed(0);
    } else if (firstVolume != null) {
      _minAltitudeFt.text = _metersToFeet(
        firstVolume.minAltitudeM,
      ).toStringAsFixed(0);
    }
    if (intent?.maxAltitudeFtAgl != null) {
      _maxAltitudeFt.text = intent!.maxAltitudeFtAgl!.toStringAsFixed(0);
    } else if (firstVolume != null) {
      _maxAltitudeFt.text = _metersToFeet(
        firstVolume.maxAltitudeM,
      ).toStringAsFixed(0);
    }
    _authorizationPath = intent?.authorizationPath.isNotEmpty == true
        ? intent!.authorizationPath
        : _authorizationPath;
    _populationCategory = intent?.populationCategory.isNotEmpty == true
        ? intent!.populationCategory
        : _populationCategory;
    _conformanceRequired = intent?.conformanceRequired ?? _conformanceRequired;
    _altitudeRef = firstVolume?.altitudeRef.isNotEmpty == true
        ? firstVolume!.altitudeRef
        : _altitudeRef;
    _volumeType = firstVolume?.volumeType ?? _volumeType;
    _bufferMeters.text =
        firstVolume?.bufferMeters?.toStringAsFixed(0) ?? _bufferMeters.text;
    final points = _pointsFromGeoJson(firstVolume?.geoJson);
    if (points.length >= 3) _volumePoints = points;
  }

  DateTime _plannedStartAt() =>
      _combinePlannedDateAndSlot(_plannedDate, _plannedStartSlot).toUtc();

  DateTime _plannedEndAt() => _combinePlannedEnd(
    _plannedDate,
    startSlot: _plannedStartSlot,
    endSlot: _plannedEndSlot,
  ).toUtc();

  String? _validateTimeWindow() {
    if (!_plannedEndAt().isAfter(_plannedStartAt())) {
      return 'Planned end must be after planned start.';
    }
    return null;
  }

  List<LatLng> _derivedVolumePolygon() {
    final widthMeters = double.tryParse(_bufferMeters.text.trim()) ?? 15;
    return _volumeShapeMode == 'precise'
        ? _preciseRouteVolume(_volumePoints, widthMeters)
        : _boxRouteVolume(_volumePoints, widthMeters);
  }

  bool get _checksClear {
    final preflight = _preflight;
    final deconfliction = _deconfliction;
    return preflight != null &&
        !preflight.blocked &&
        deconfliction != null &&
        deconfliction.clear;
  }

  bool get _editingLocked =>
      _activatedIntent != null || _intent?.status == 'active';

  @override
  Widget build(BuildContext context) {
    final editingLocked = _editingLocked;
    return Container(
      decoration: const BoxDecoration(gradient: aeroPageGradient),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    aircraftId: widget.aircraftId,
                    modifying: _sourceIntent != null,
                  ),
                  const SizedBox(height: 12),
                  _IntentContextBanner(
                    aircraftId: widget.aircraftId,
                    sourceIntent: _sourceIntent,
                  ),
                  const SizedBox(height: 18),
                  _VolumesPanel(
                    points: _volumePoints,
                    deconfliction: _deconfliction,
                    bufferMeters: _bufferMeters,
                    altitudeRef: _altitudeRef,
                    volumeType: _volumeType,
                    volumeShapeMode: _volumeShapeMode,
                    locked: editingLocked,
                    onLoadDefault: () {
                      setState(
                        () => _volumePoints = _defaultRoutePoints(
                          center: _initialVolumeCenter,
                        ),
                      );
                    },
                    onAddPoint: (point) {
                      setState(() => _volumePoints = [..._volumePoints, point]);
                    },
                    onRemovePoint: (index) {
                      setState(() {
                        _volumePoints = [
                          for (var i = 0; i < _volumePoints.length; i++)
                            if (i != index) _volumePoints[i],
                        ];
                      });
                    },
                    onUndoPoint: () {
                      if (_volumePoints.isEmpty) return;
                      setState(() {
                        _volumePoints = _volumePoints
                            .take(_volumePoints.length - 1)
                            .toList();
                      });
                    },
                    onAltitudeRefChanged: (value) {
                      if (value != null) setState(() => _altitudeRef = value);
                    },
                    onVolumeTypeChanged: (value) {
                      if (value != null) setState(() => _volumeType = value);
                    },
                    onShapeModeChanged: (value) {
                      if (value != null) {
                        setState(() => _volumeShapeMode = value);
                      }
                    },
                    onBufferMetersChanged: (_) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 18),
                  TwoColumn(
                    breakpoint: 1180,
                    left: _MissionPanel(
                      aircraftId: widget.aircraftId,
                      missionName: _missionName,
                      summary: _summary,
                      useCase: _useCase,
                      routeSummary: _routeSummary,
                      plannedDate: _plannedDate,
                      plannedStartSlot: _plannedStartSlot,
                      plannedEndSlot: _plannedEndSlot,
                      minAltitude: _minAltitudeFt,
                      maxAltitude: _maxAltitudeFt,
                      supervisorId: _supervisorId,
                      coordinatorId: _coordinatorId,
                      authorizationPath: _authorizationPath,
                      populationCategory: _populationCategory,
                      conformanceRequired: _conformanceRequired,
                      locked: editingLocked,
                      onAuthorizationChanged: (value) {
                        if (value != null) {
                          setState(() => _authorizationPath = value);
                        }
                      },
                      onPopulationChanged: (value) {
                        if (value != null) {
                          setState(() => _populationCategory = value);
                        }
                      },
                      onDateChanged: (value) {
                        setState(() => _plannedDate = value);
                      },
                      onStartSlotChanged: (value) {
                        if (value != null) {
                          setState(() => _plannedStartSlot = value);
                        }
                      },
                      onEndSlotChanged: (value) {
                        if (value != null) {
                          setState(() => _plannedEndSlot = value);
                        }
                      },
                      onConformanceChanged: (value) {
                        setState(() => _conformanceRequired = value);
                      },
                    ),
                    right: Column(
                      children: [
                        _ChecksPanel(
                          busy: _busy,
                          sourceIntent: _sourceIntent,
                          modifyResult: _modifyResult,
                          intent: _intent,
                          volume: _volume,
                          preflight: _preflight,
                          deconfliction: _deconfliction,
                          onRunChecks: _saveAndCheck,
                        ),
                        const SizedBox(height: 18),
                        _ReviewPanel(
                          aircraftId: widget.aircraftId,
                          intent: _intent,
                          volume: _volume,
                          preflight: _preflight,
                          deconfliction: _deconfliction,
                          activatedIntent: _activatedIntent,
                          checksClear: _checksClear,
                          busy: _busy,
                          onRunChecks: _saveAndCheck,
                          onAccept: _acceptIntent,
                          onActivate: _activateIntent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 22,
              right: 22,
              top: 14,
              child: _WorkflowErrorBanner(
                message: _error!,
                onDismiss: () {
                  setState(() => _error = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkflowErrorBanner extends StatelessWidget {
  const _WorkflowErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF171E34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4A100)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE4A100),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Needs attention',
                        style: TextStyle(
                          color: Color(0xFFF0C15A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFD8E0F4),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  color: const Color(0xFFC8D2EE),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.aircraftId, required this.modifying});

  final String aircraftId;
  final bool modifying;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          modifying ? 'Modify Mission Intent' : 'New Mission Intent',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 42),
        ),
        const SizedBox(height: 8),
        Text(
          'Aircraft $aircraftId',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7F90B6)),
        ),
      ],
    );
  }
}

class _IntentContextBanner extends StatelessWidget {
  const _IntentContextBanner({
    required this.aircraftId,
    required this.sourceIntent,
  });

  final String aircraftId;
  final OperationalIntent? sourceIntent;

  @override
  Widget build(BuildContext context) {
    final intent = sourceIntent;
    final title = intent == null
        ? 'Creating new intent'
        : 'Modifying assigned intent';
    final detail = intent == null
        ? 'Aircraft $aircraftId'
        : '${intent.name} v${intent.version} - Aircraft $aircraftId';
    final icon = intent == null
        ? Icons.add_task_outlined
        : Icons.assignment_returned_outlined;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151D33),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF293654)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8EA2FF), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFD6E0FF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: Color(0xFF93A3C7),
                      height: 1.3,
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

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({
    required this.aircraftId,
    required this.missionName,
    required this.summary,
    required this.useCase,
    required this.routeSummary,
    required this.plannedDate,
    required this.plannedStartSlot,
    required this.plannedEndSlot,
    required this.minAltitude,
    required this.maxAltitude,
    required this.supervisorId,
    required this.coordinatorId,
    required this.authorizationPath,
    required this.populationCategory,
    required this.conformanceRequired,
    required this.locked,
    required this.onAuthorizationChanged,
    required this.onPopulationChanged,
    required this.onDateChanged,
    required this.onStartSlotChanged,
    required this.onEndSlotChanged,
    required this.onConformanceChanged,
  });

  final String aircraftId;
  final TextEditingController missionName;
  final TextEditingController summary;
  final TextEditingController useCase;
  final TextEditingController routeSummary;
  final DateTime plannedDate;
  final String plannedStartSlot;
  final String plannedEndSlot;
  final TextEditingController minAltitude;
  final TextEditingController maxAltitude;
  final TextEditingController supervisorId;
  final TextEditingController coordinatorId;
  final String authorizationPath;
  final String populationCategory;
  final bool conformanceRequired;
  final bool locked;
  final ValueChanged<String?> onAuthorizationChanged;
  final ValueChanged<String?> onPopulationChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onStartSlotChanged;
  final ValueChanged<String?> onEndSlotChanged;
  final ValueChanged<bool> onConformanceChanged;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Mission',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DetailLine(label: 'Aircraft', value: aircraftId),
            if (locked)
              const DetailLine(
                label: 'Edit state',
                value: 'Active intents are locked from this workflow.',
              ),
            const SizedBox(height: 8),
            _TextField(
              controller: missionName,
              label: 'Mission name',
              enabled: !locked,
              validator: _required,
            ),
            const SizedBox(height: 12),
            _TextField(
              controller: summary,
              label: 'Summary',
              enabled: !locked,
              minLines: 2,
              maxLines: 4,
              validator: _required,
            ),
            const SizedBox(height: 12),
            _ResponsiveFields(
              children: [
                _TextField(
                  controller: useCase,
                  label: 'Use case',
                  enabled: !locked,
                ),
                _TextField(
                  controller: routeSummary,
                  label: 'Route summary',
                  enabled: !locked,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ResponsiveFields(
              children: [
                _DateField(
                  label: 'Mission date',
                  value: plannedDate,
                  enabled: !locked,
                  onChanged: onDateChanged,
                ),
                _SelectField(
                  label: 'Start time',
                  value: plannedStartSlot,
                  enabled: !locked,
                  options: _timeSlotOptions,
                  formatOption: _formatTimeSlot,
                  onChanged: onStartSlotChanged,
                ),
                _SelectField(
                  label: 'End time',
                  value: plannedEndSlot,
                  enabled: !locked,
                  options: _timeSlotOptions,
                  formatOption: _formatTimeSlot,
                  onChanged: onEndSlotChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ResponsiveFields(
              children: [
                _TextField(
                  controller: minAltitude,
                  label: 'Min ft AGL',
                  keyboardType: TextInputType.number,
                  enabled: !locked,
                  validator: _number,
                ),
                _TextField(
                  controller: maxAltitude,
                  label: 'Max ft AGL',
                  keyboardType: TextInputType.number,
                  enabled: !locked,
                  validator: _number,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ResponsiveFields(
              children: [
                _SelectField(
                  label: 'Authorization',
                  value: authorizationPath,
                  enabled: !locked,
                  options: const [
                    'unknown',
                    'demo',
                    'laanc',
                    'part_107',
                    'coa',
                  ],
                  onChanged: onAuthorizationChanged,
                ),
                _SelectField(
                  label: 'Population',
                  value: populationCategory,
                  enabled: !locked,
                  options: const ['unknown', 'cat_1', 'cat_2', 'cat_3'],
                  onChanged: onPopulationChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ResponsiveFields(
              children: [
                _TextField(
                  controller: supervisorId,
                  label: 'Supervisor ID',
                  enabled: !locked,
                ),
                _TextField(
                  controller: coordinatorId,
                  label: 'Flight coordinator ID',
                  enabled: !locked,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conformance monitoring required'),
              value: conformanceRequired,
              onChanged: locked ? null : onConformanceChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumesPanel extends StatelessWidget {
  const _VolumesPanel({
    required this.points,
    required this.deconfliction,
    required this.bufferMeters,
    required this.altitudeRef,
    required this.volumeType,
    required this.volumeShapeMode,
    required this.locked,
    required this.onLoadDefault,
    required this.onAddPoint,
    required this.onRemovePoint,
    required this.onUndoPoint,
    required this.onAltitudeRefChanged,
    required this.onVolumeTypeChanged,
    required this.onShapeModeChanged,
    required this.onBufferMetersChanged,
  });

  final List<LatLng> points;
  final DeconflictionResult? deconfliction;
  final TextEditingController bufferMeters;
  final String altitudeRef;
  final String volumeType;
  final String volumeShapeMode;
  final bool locked;
  final VoidCallback onLoadDefault;
  final ValueChanged<LatLng> onAddPoint;
  final ValueChanged<int> onRemovePoint;
  final VoidCallback onUndoPoint;
  final ValueChanged<String?> onAltitudeRefChanged;
  final ValueChanged<String?> onVolumeTypeChanged;
  final ValueChanged<String?> onShapeModeChanged;
  final ValueChanged<String> onBufferMetersChanged;

  @override
  Widget build(BuildContext context) {
    final center = points.isEmpty
        ? const LatLng(35.4676, -97.5164)
        : points.first;
    final widthMeters = double.tryParse(bufferMeters.text.trim()) ?? 15;
    final volumePolygon = volumeShapeMode == 'precise'
        ? _preciseRouteVolume(points, widthMeters)
        : _boxRouteVolume(points, widthMeters);
    final conflictBoxes = _conflictingBoundingBoxes(deconfliction);
    final conflictsWithoutGeometry = _conflictingFindings(
      deconfliction,
    ).where((finding) => finding.conflictingBounds == null).length;
    return Panel(
      title: 'Volume',
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton.filledTonal(
            tooltip: 'Undo point',
            onPressed: locked || points.isEmpty ? null : onUndoPoint,
            icon: const Icon(Icons.undo),
          ),
          IconButton.filledTonal(
            tooltip: 'Reset route start',
            onPressed: locked ? null : onLoadDefault,
            icon: const Icon(Icons.polyline_outlined),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locked)
              const DetailLine(
                label: 'Edit state',
                value: 'Active intents are locked from this workflow.',
              ),
            _ResponsiveFields(
              children: [
                _SelectField(
                  label: 'Volume shape',
                  value: volumeShapeMode,
                  enabled: !locked,
                  options: const ['box', 'precise'],
                  onChanged: onShapeModeChanged,
                ),
                _SelectField(
                  label: 'Altitude ref',
                  value: altitudeRef,
                  enabled: !locked,
                  options: const ['agl', 'amsl'],
                  onChanged: onAltitudeRefChanged,
                ),
                _SelectField(
                  label: 'Volume type',
                  value: volumeType,
                  enabled: !locked,
                  options: const ['loiter', 'transit', 'survey'],
                  onChanged: onVolumeTypeChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15,
                    onTap: locked ? null : (_, point) => onAddPoint(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'aero_arc_web',
                    ),
                    if (volumePolygon.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: volumePolygon,
                            color: const Color(
                              0xFF5A6BFF,
                            ).withValues(alpha: 0.20),
                            borderColor: const Color(0xFF7A89FF),
                            borderStrokeWidth: 2,
                          ),
                          for (final conflictBox in conflictBoxes)
                            Polygon(
                              points: conflictBox,
                              color: const Color(
                                0xFFE4A100,
                              ).withValues(alpha: 0.22),
                              borderColor: const Color(0xFFE4A100),
                              borderStrokeWidth: 3,
                            ),
                        ],
                      ),
                    if (points.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 3,
                            color: const Color(0xFF00CFA0),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < points.length; i++)
                          Marker(
                            point: points[i],
                            width: 40,
                            height: 40,
                            child: _VolumePointMarker(
                              index: i,
                              locked: locked,
                              onRemove: () => onRemovePoint(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  label: volumePolygon.length >= 3 ? 'ready' : 'draft',
                  icon: Icons.polyline_outlined,
                ),
                StatusBadge(label: volumeShapeMode, icon: Icons.route),
                if (conflictBoxes.isNotEmpty)
                  const StatusBadge(
                    label: 'potential_conflict',
                    icon: Icons.crop_square,
                  ),
                Text(
                  '${points.length} point(s)',
                  style: const TextStyle(color: Color(0xFF93A3C7)),
                ),
                if (!locked)
                  Text(
                    volumeShapeMode == 'precise'
                        ? 'Click route points. Precise mode buffers the route by the width below.'
                        : 'Click route points. Box mode wraps the route in one expanded box.',
                    style: const TextStyle(color: Color(0xFF7F90B6)),
                  ),
                if (conflictsWithoutGeometry > 0)
                  Text(
                    '$conflictsWithoutGeometry conflict(s) do not include box geometry.',
                    style: const TextStyle(color: Color(0xFFE4A100)),
                  ),
              ],
            ),
            if (_conflictingFindings(deconfliction).isNotEmpty) ...[
              const SizedBox(height: 12),
              _ConflictFindingList(
                findings: _conflictingFindings(deconfliction),
              ),
            ],
            const SizedBox(height: 12),
            _TextField(
              controller: bufferMeters,
              label: volumeShapeMode == 'precise'
                  ? 'Route width meters'
                  : 'Box padding meters',
              keyboardType: TextInputType.number,
              enabled: !locked,
              onChanged: onBufferMetersChanged,
              validator: _optionalNumber,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictFindingList extends StatelessWidget {
  const _ConflictFindingList({required this.findings});

  final List<ConflictFinding> findings;

  @override
  Widget build(BuildContext context) {
    return RowList(
      children: [
        for (final finding in findings)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                finding.conflictingBounds == null
                    ? Icons.warning_amber_rounded
                    : Icons.crop_square,
                color: const Color(0xFFE4A100),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      finding.conflictingIntentId == null
                          ? 'Conflict source unavailable'
                          : 'Intent ${finding.conflictingIntentId}',
                      style: const TextStyle(
                        color: Color(0xFFD6E0FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _conflictFindingDetail(finding),
                      style: const TextStyle(
                        color: Color(0xFF93A3C7),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _VolumePointMarker extends StatelessWidget {
  const _VolumePointMarker({
    required this.index,
    required this.locked,
    required this.onRemove,
  });

  final int index;
  final bool locked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: locked
          ? 'Volume point ${index + 1}'
          : 'Remove point ${index + 1}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: locked ? null : onRemove,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00CFA0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF03111B),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecksPanel extends StatelessWidget {
  const _ChecksPanel({
    required this.busy,
    required this.sourceIntent,
    required this.modifyResult,
    required this.intent,
    required this.volume,
    required this.preflight,
    required this.deconfliction,
    required this.onRunChecks,
  });

  final bool busy;
  final OperationalIntent? sourceIntent;
  final ModifyOperationalIntentResult? modifyResult;
  final OperationalIntent? intent;
  final OperationalVolume? volume;
  final PreflightEvaluationResult? preflight;
  final DeconflictionResult? deconfliction;
  final VoidCallback onRunChecks;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Checks',
      trailing: IconButton.filledTonal(
        tooltip: 'Run checks',
        onPressed: busy ? null : onRunChecks,
        icon: const Icon(Icons.refresh),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 4),
              ),
            DetailLine(label: 'Intent', value: intent?.id ?? 'Not created'),
            if (sourceIntent != null)
              DetailLine(
                label: 'Source',
                value: '${sourceIntent!.id} v${sourceIntent!.version}',
              ),
            if (modifyResult?.supersedesIntentId != null)
              DetailLine(
                label: 'Supersedes',
                value:
                    '${modifyResult!.supersedesIntentId} v${modifyResult!.supersedesVersion}',
              ),
            DetailLine(label: 'Status', value: intent?.status ?? 'Draft form'),
            DetailLine(label: 'Volume', value: volume?.id ?? 'Not saved'),
            DetailLine(
              label: 'Preflight',
              value: preflight == null
                  ? 'Not run'
                  : preflight!.blocked
                  ? 'Blocked'
                  : 'Clear',
            ),
            DetailLine(
              label: 'Checks',
              value: preflight == null
                  ? 'Not available'
                  : '${preflight!.checks.length} preflight check(s)',
            ),
            DetailLine(
              label: 'Deconfliction',
              value: deconfliction == null
                  ? 'Not run'
                  : displayEnum(deconfliction!.posture),
            ),
            if (deconfliction != null)
              DetailLine(
                label: 'Findings',
                value:
                    '${deconfliction!.findings.length} finding(s), ${deconfliction!.findings.where((finding) => finding.blocking).length} blocking',
              ),
            if (deconfliction != null &&
                deconfliction!.findings.isNotEmpty) ...[
              const SizedBox(height: 8),
              RowList(
                children: [
                  for (final finding in deconfliction!.findings)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(label: finding.status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            finding.message,
                            style: const TextStyle(
                              color: Color(0xFFC4D0EE),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.aircraftId,
    required this.intent,
    required this.volume,
    required this.preflight,
    required this.deconfliction,
    required this.activatedIntent,
    required this.checksClear,
    required this.busy,
    required this.onRunChecks,
    required this.onAccept,
    required this.onActivate,
  });

  final String aircraftId;
  final OperationalIntent? intent;
  final OperationalVolume? volume;
  final PreflightEvaluationResult? preflight;
  final DeconflictionResult? deconfliction;
  final OperationalIntent? activatedIntent;
  final bool checksClear;
  final bool busy;
  final VoidCallback onRunChecks;
  final VoidCallback onAccept;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final accepted = intent?.status == 'accepted' || intent?.status == 'active';
    final activationBlockers = _activationBlockers(
      intent: intent,
      preflight: preflight,
      deconfliction: deconfliction,
      accepted: accepted,
    );
    final acceptanceBlockedReason = _acceptanceBlockedReason(
      intent: intent,
      preflight: preflight,
      deconfliction: deconfliction,
      accepted: accepted,
    );
    return Panel(
      title: 'Review',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            DetailLine(label: 'Aircraft', value: aircraftId),
            DetailLine(label: 'Mission', value: intent?.name ?? 'Not created'),
            DetailLine(label: 'Intent ID', value: intent?.id ?? 'Not created'),
            DetailLine(label: 'Version', value: '${intent?.version ?? 0}'),
            DetailLine(label: 'Volume ID', value: volume?.id ?? 'Not saved'),
            DetailLine(
              label: 'Window',
              value: intent == null
                  ? 'Not created'
                  : '${formatDate(intent!.plannedStartAt)} -> ${formatDate(intent!.plannedEndAt)}',
            ),
            DetailLine(
              label: 'Altitude',
              value: intent == null
                  ? 'Not created'
                  : formatFeetRange(
                      intent!.minAltitudeFtAgl,
                      intent!.maxAltitudeFtAgl,
                    ),
            ),
            DetailLine(
              label: 'Preflight',
              value: preflight == null
                  ? 'Not run'
                  : preflight!.blocked
                  ? 'Blocked'
                  : 'Clear',
            ),
            DetailLine(
              label: 'Deconfliction',
              value: deconfliction == null
                  ? 'Not run'
                  : displayEnum(deconfliction!.posture),
            ),
            _ActionDetailLine(
              label: 'Activation',
              value: activatedIntent != null
                  ? 'Active'
                  : acceptanceBlockedReason == null || accepted
                  ? 'Ready after acceptance'
                  : acceptanceBlockedReason,
              onPressed:
                  activatedIntent == null && activationBlockers.isNotEmpty
                  ? () => _showActivationBlockersDialog(
                      context,
                      activationBlockers,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onRunChecks,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: const Text('Save & check'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || acceptanceBlockedReason != null
                        ? null
                        : onAccept,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || !checksClear || !accepted
                        ? null
                        : onActivate,
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Activate'),
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

class _ActionDetailLine extends StatelessWidget {
  const _ActionDetailLine({
    required this.label,
    required this.value,
    this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? 'Not provided' : value;
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
            child: onPressed == null
                ? Text(
                    displayValue,
                    style: const TextStyle(
                      color: Color(0xFFC4D0EE),
                      height: 1.35,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(displayValue),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE4A100),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.validator,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFFC9D5F4)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF06122C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      initialValue: value,
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled
              ? () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: value,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (selected == null) return;
                  field.didChange(selected);
                  onChanged(selected);
                }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              enabled: enabled,
              filled: true,
              fillColor: const Color(0xFF06122C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: Text(_formatDateOnly(value))),
                const Icon(Icons.calendar_month),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.formatOption,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? formatOption;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(formatOption?.call(option) ?? displayEnum(option)),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF06122C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}

String? _number(String? value) {
  final required = _required(value);
  if (required != null) return required;
  return double.tryParse(value!.trim()) == null ? 'Enter a number' : null;
}

String? _optionalNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return double.tryParse(value.trim()) == null ? 'Enter a number' : null;
}

String? _acceptanceBlockedReason({
  required OperationalIntent? intent,
  required PreflightEvaluationResult? preflight,
  required DeconflictionResult? deconfliction,
  required bool accepted,
}) {
  if (intent == null) return 'Save and run checks before acceptance';
  if (accepted) return 'Already accepted';
  if (preflight == null) return 'Run preflight checks before acceptance';
  if (preflight.blocked) return _preflightBlockedReason(preflight);
  if (deconfliction == null) return 'Run deconfliction before acceptance';
  if (!deconfliction.clear) {
    return 'Deconfliction posture is ${displayEnum(deconfliction.posture)}';
  }
  return null;
}

List<_ActivationBlocker> _activationBlockers({
  required OperationalIntent? intent,
  required PreflightEvaluationResult? preflight,
  required DeconflictionResult? deconfliction,
  required bool accepted,
}) {
  final blockers = <_ActivationBlocker>[];
  if (intent == null) {
    blockers.add(
      const _ActivationBlocker(
        title: 'Intent not created',
        detail: 'Save and run checks before acceptance.',
        status: 'missing',
      ),
    );
    return blockers;
  }
  if (preflight == null) {
    blockers.add(
      const _ActivationBlocker(
        title: 'Preflight not run',
        detail: 'Run preflight checks before acceptance.',
        status: 'not_run',
      ),
    );
  } else {
    final blockingChecks =
        preflight.checks.where((check) => check.blocking).toList()
          ..sort((left, right) {
            final leftPriority = _preflightBlockerPriority(left);
            final rightPriority = _preflightBlockerPriority(right);
            if (leftPriority != rightPriority) {
              return leftPriority - rightPriority;
            }
            return left.summary.compareTo(right.summary);
          });
    for (final check in blockingChecks) {
      final code =
          check.requirementCode == null || check.requirementCode!.isEmpty
          ? displayEnum(check.category)
          : check.requirementCode!;
      blockers.add(
        _ActivationBlocker(
          title: code,
          detail: check.summary,
          status: check.status,
          metadata: [displayEnum(check.category), displayEnum(check.source)],
        ),
      );
    }
  }
  if (deconfliction == null) {
    blockers.add(
      const _ActivationBlocker(
        title: 'Deconfliction not run',
        detail: 'Run deconfliction before acceptance.',
        status: 'not_run',
      ),
    );
  } else if (!deconfliction.clear) {
    final blockingFindings = deconfliction.findings
        .where((finding) => finding.blocking)
        .toList();
    if (blockingFindings.isEmpty) {
      blockers.add(
        _ActivationBlocker(
          title: 'Deconfliction posture',
          detail: 'Posture is ${displayEnum(deconfliction.posture)}.',
          status: deconfliction.posture,
        ),
      );
    } else {
      for (final finding in blockingFindings) {
        blockers.add(
          _ActivationBlocker(
            title: 'Deconfliction finding',
            detail: finding.message,
            status: finding.status,
            metadata: [
              if (finding.conflictingIntentId != null)
                'Intent ${finding.conflictingIntentId}',
              if (finding.conflictingVolumeId != null)
                'Volume ${finding.conflictingVolumeId}',
            ],
          ),
        );
      }
    }
  }
  if (!accepted && blockers.isEmpty) {
    blockers.add(
      const _ActivationBlocker(
        title: 'Intent not accepted',
        detail: 'Accept the intent before activation.',
        status: 'pending',
      ),
    );
  }
  return blockers;
}

void _showActivationBlockersDialog(
  BuildContext context,
  List<_ActivationBlocker> blockers,
) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Activation blockers'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: RowList(
              children: [
                for (final blocker in blockers)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(label: blocker.status),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blocker.title,
                              style: const TextStyle(
                                color: Color(0xFFD6E0FF),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              blocker.detail,
                              style: const TextStyle(
                                color: Color(0xFFC4D0EE),
                                height: 1.35,
                              ),
                            ),
                            if (blocker.metadata.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                blocker.metadata.join(' / '),
                                style: const TextStyle(
                                  color: Color(0xFF7F90B6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ActivationBlocker {
  const _ActivationBlocker({
    required this.title,
    required this.detail,
    required this.status,
    this.metadata = const [],
  });

  final String title;
  final String detail;
  final String status;
  final List<String> metadata;
}

String _preflightBlockedReason(PreflightEvaluationResult preflight) {
  final blocking = preflight.checks.where((check) => check.blocking).toList();
  if (blocking.isEmpty) return 'Preflight is blocked';
  blocking.sort((left, right) {
    final leftPriority = _preflightBlockerPriority(left);
    final rightPriority = _preflightBlockerPriority(right);
    if (leftPriority != rightPriority) return leftPriority - rightPriority;
    return left.summary.compareTo(right.summary);
  });
  final first = blocking.first;
  final code = first.requirementCode == null || first.requirementCode!.isEmpty
      ? displayEnum(first.category)
      : first.requirementCode!;
  if (blocking.length == 1) return '$code: ${first.summary}';
  return '$code: ${first.summary} (+${blocking.length - 1} more)';
}

int _preflightBlockerPriority(PreflightCheck check) {
  return switch (check.requirementCode) {
    'BATTERY-SOH-80' => 0,
    'BATTERY-SOH-KNOWN' => 1,
    'BATTERY-INSTALLED' => 2,
    'MX-CRITICAL-OPEN' => 3,
    'RID-ONLINE' => 4,
    'AIRCRAFT-STATUS' => 5,
    'AIRCRAFT-EXISTS' => 6,
    'VOLUME-EXISTS' => 7,
    'VOLUME-WINDOW' => 8,
    'VOLUME-IN-INTENT' => 9,
    'VOLUME-ALTITUDE' => 10,
    'VOLUME-GEOJSON' => 11,
    'INTENT-WINDOW' => 12,
    _ => 100,
  };
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _feetToMeters(double feet) => feet * 0.3048;
double _metersToFeet(double meters) => meters / 0.3048;

final List<String> _timeSlotOptions = List.generate(96, (index) {
  final totalMinutes = index * 15;
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${_twoDigits(hour)}:${_twoDigits(minute)}';
});

DateTime _roundUpToSlot(DateTime value) {
  final minute = ((value.minute + 14) ~/ 15) * 15;
  return DateTime(value.year, value.month, value.day, value.hour, minute);
}

String _slotForTime(DateTime value) {
  final rounded = _roundUpToSlot(value);
  return '${_twoDigits(rounded.hour)}:${_twoDigits(rounded.minute)}';
}

DateTime _combinePlannedDateAndSlot(DateTime date, String slot) {
  final parts = slot.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return DateTime(date.year, date.month, date.day, hour, minute);
}

DateTime _combinePlannedEnd(
  DateTime date, {
  required String startSlot,
  required String endSlot,
}) {
  final start = _combinePlannedDateAndSlot(date, startSlot);
  final end = _combinePlannedDateAndSlot(date, endSlot);
  return end.isAfter(start) ? end : end.add(const Duration(days: 1));
}

String _formatTimeSlot(String slot) {
  final parts = slot.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final suffix = hour >= 12 ? 'PM' : 'AM';
  var displayHour = hour % 12;
  if (displayHour == 0) displayHour = 12;
  return '$displayHour:${_twoDigits(minute)} $suffix';
}

String _formatDateOnly(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

List<LatLng> _pointsFromGeoJson(String? geoJson) {
  if (geoJson == null || geoJson.trim().isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(geoJson);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic>) return const [];
  Object? coordinates = decoded['coordinates'];
  if (decoded['type'] == 'Feature') {
    final geometry = decoded['geometry'];
    if (geometry is! Map<String, dynamic>) return const [];
    coordinates = geometry['coordinates'];
  }
  if (coordinates is! List || coordinates.isEmpty) return const [];
  final exterior = coordinates.first;
  if (exterior is! List) return const [];
  final points = <LatLng>[];
  for (final coordinate in exterior) {
    if (coordinate is List && coordinate.length >= 2) {
      final lon = coordinate[0];
      final lat = coordinate[1];
      if (lat is num && lon is num) {
        final point = LatLng(lat.toDouble(), lon.toDouble());
        if (points.isEmpty ||
            points.first.latitude != point.latitude ||
            points.first.longitude != point.longitude) {
          points.add(point);
        }
      }
    }
  }
  return points;
}

List<ConflictFinding> _conflictingFindings(DeconflictionResult? deconfliction) {
  if (deconfliction == null) return const [];
  return deconfliction.findings.where((finding) {
    final status = finding.status.toLowerCase();
    return finding.blocking &&
        (status == 'conflict' || status == 'potential_conflict') &&
        finding.message.toLowerCase().contains('bounding box');
  }).toList();
}

List<List<LatLng>> _conflictingBoundingBoxes(
  DeconflictionResult? deconfliction,
) {
  return [
    for (final finding in _conflictingFindings(deconfliction))
      if (finding.conflictingBounds != null)
        _boundsPolygon(finding.conflictingBounds!),
  ];
}

List<LatLng> _boundsPolygon(GeoBounds bounds) {
  return [
    LatLng(bounds.minLatitude, bounds.minLongitude),
    LatLng(bounds.minLatitude, bounds.maxLongitude),
    LatLng(bounds.maxLatitude, bounds.maxLongitude),
    LatLng(bounds.maxLatitude, bounds.minLongitude),
  ];
}

String _conflictFindingDetail(ConflictFinding finding) {
  final parts = <String>[
    if (finding.conflictingVolumeId != null)
      'Volume ${finding.conflictingVolumeId}',
    displayEnum(finding.status),
    if (finding.timeOverlapStart != null && finding.timeOverlapEnd != null)
      '${formatDate(finding.timeOverlapStart)} -> ${formatDate(finding.timeOverlapEnd)}',
    if (finding.altitudeOverlapMin != null &&
        finding.altitudeOverlapMax != null)
      '${finding.altitudeOverlapMin!.toStringAsFixed(1)}-${finding.altitudeOverlapMax!.toStringAsFixed(1)} m overlap',
    if (finding.conflictingBounds == null) 'No conflict box geometry returned',
  ];
  return parts.join('\n');
}

List<LatLng> _defaultRoutePoints({LatLng? center}) {
  final centerLat = center?.latitude ?? 35.4676;
  final centerLon = center?.longitude ?? -97.5164;
  return [LatLng(centerLat, centerLon)];
}

List<LatLng> _boxRouteVolume(List<LatLng> route, double paddingMeters) {
  if (route.length < 2) return const [];
  final minLat = route.map((point) => point.latitude).reduce(math.min);
  final maxLat = route.map((point) => point.latitude).reduce(math.max);
  final minLon = route.map((point) => point.longitude).reduce(math.min);
  final maxLon = route.map((point) => point.longitude).reduce(math.max);
  final centerLat = (minLat + maxLat) / 2;
  final latPadding = _metersToLatitudeDegrees(paddingMeters);
  final lonPadding = _metersToLongitudeDegrees(paddingMeters, centerLat);
  return [
    LatLng(minLat - latPadding, minLon - lonPadding),
    LatLng(minLat - latPadding, maxLon + lonPadding),
    LatLng(maxLat + latPadding, maxLon + lonPadding),
    LatLng(maxLat + latPadding, minLon - lonPadding),
  ];
}

List<LatLng> _preciseRouteVolume(List<LatLng> route, double widthMeters) {
  if (route.length < 2) return const [];
  final halfWidth = math.max(widthMeters / 2, 1);
  final left = <LatLng>[];
  final right = <LatLng>[];
  for (var i = 0; i < route.length; i++) {
    final previous = i == 0 ? route[i] : route[i - 1];
    final next = i == route.length - 1 ? route[i] : route[i + 1];
    final vector = _meterVector(previous, next);
    final length = math.sqrt(vector.dx * vector.dx + vector.dy * vector.dy);
    if (length == 0) continue;
    final normalX = -vector.dy / length;
    final normalY = vector.dx / length;
    left.add(_offsetPoint(route[i], normalX * halfWidth, normalY * halfWidth));
    right.add(
      _offsetPoint(route[i], -normalX * halfWidth, -normalY * halfWidth),
    );
  }
  if (left.length < 2 || right.length < 2) {
    return _boxRouteVolume(route, widthMeters);
  }
  return [...left, ...right.reversed];
}

_MeterVector _meterVector(LatLng from, LatLng to) {
  final averageLat = (from.latitude + to.latitude) / 2;
  return _MeterVector(
    (to.longitude - from.longitude) * _metersPerLongitudeDegree(averageLat),
    (to.latitude - from.latitude) * _metersPerLatitudeDegree,
  );
}

LatLng _offsetPoint(LatLng point, double eastMeters, double northMeters) {
  return LatLng(
    point.latitude + _metersToLatitudeDegrees(northMeters),
    point.longitude + _metersToLongitudeDegrees(eastMeters, point.latitude),
  );
}

const double _metersPerLatitudeDegree = 111320;

double _metersPerLongitudeDegree(double latitude) {
  final scale = math.cos(latitude * math.pi / 180).abs();
  return _metersPerLatitudeDegree * math.max(scale, 0.01);
}

double _metersToLatitudeDegrees(double meters) =>
    meters / _metersPerLatitudeDegree;

double _metersToLongitudeDegrees(double meters, double latitude) {
  return meters / _metersPerLongitudeDegree(latitude);
}

class _MeterVector {
  const _MeterVector(this.dx, this.dy);

  final double dx;
  final double dy;
}

String _polygonGeoJson(List<LatLng> points) {
  final coordinates = [
    for (final point in points) [point.longitude, point.latitude],
    [points.first.longitude, points.first.latitude],
  ];
  return const JsonEncoder.withIndent('  ').convert({
    'type': 'Polygon',
    'coordinates': [coordinates],
  });
}
