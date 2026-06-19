import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/aero_arc_api.dart';
import '../models/aero_arc_models.dart';
import '../widgets/dashboard_ui.dart';

class IntentWorkflowPage extends StatefulWidget {
  const IntentWorkflowPage({
    super.key,
    required this.aircraftId,
    this.apiClient,
    this.initialIntent,
    this.initialVolumes = const [],
  });

  final String aircraftId;
  final AeroArcApiClient? apiClient;
  final OperationalIntent? initialIntent;
  final List<OperationalVolume> initialVolumes;

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
  late final TextEditingController _plannedStart;
  late final TextEditingController _plannedEnd;

  bool _conformanceRequired = true;
  bool _busy = false;
  String _authorizationPath = 'demo';
  String _populationCategory = 'cat_1';
  String _altitudeRef = 'agl';
  String _volumeType = 'loiter';
  String? _error;
  OperationalIntent? _sourceIntent;
  OperationalIntent? _intent;
  OperationalVolume? _volume;
  ModifyOperationalIntentResult? _modifyResult;
  PreflightEvaluationResult? _preflight;
  DeconflictionResult? _deconfliction;
  OperationalIntent? _acceptedIntent;
  OperationalIntent? _activatedIntent;
  List<LatLng> _volumePoints = _defaultVolumePoints();

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? AeroArcApiClient();
    final now = DateTime.now().add(const Duration(minutes: 15));
    _plannedStart = TextEditingController(text: _formatInputDate(now));
    _plannedEnd = TextEditingController(
      text: _formatInputDate(now.add(const Duration(hours: 1))),
    );
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
    _plannedStart.dispose();
    _plannedEnd.dispose();
    super.dispose();
  }

  Future<void> _saveAndCheck() async {
    if (!_formKey.currentState!.validate()) return;
    if (_volumePoints.length < 3) {
      setState(() => _error = 'Draw at least three volume points on the map.');
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
        _modifyResult = modified;
      } else if (intent == null && source != null) {
        final modified = await _apiClient.modifyOperationalIntent(
          source.id,
          _modifyRequest(source),
        );
        intent = modified.intent;
        volume = modified.volumes.isEmpty ? null : modified.volumes.first;
        _modifyResult = modified;
      } else {
        intent ??= await _apiClient.createOperationalIntent(_intentRequest());
        volume ??= await _apiClient.addOperationalIntentVolume(
          intent.id,
          _volumeRequest(),
        );
      }
      final submitted = intent.status == 'draft'
          ? await _apiClient.submitOperationalIntent(intent.id)
          : intent;
      final preflight = await _apiClient.evaluateOperationalIntentPreflight(
        submitted.id,
      );
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
      plannedStartAt: _parseInputDate(_plannedStart.text),
      plannedEndAt: _parseInputDate(_plannedEnd.text),
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
      geoJson: _polygonGeoJson(_volumePoints),
      minAltitudeM: _feetToMeters(minFt),
      maxAltitudeM: _feetToMeters(maxFt),
      altitudeRef: _altitudeRef,
      startsAt: _parseInputDate(_plannedStart.text),
      endsAt: _parseInputDate(_plannedEnd.text),
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
        plannedStartAt: _parseInputDate(_plannedStart.text),
        plannedEndAt: _parseInputDate(_plannedEnd.text),
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
      _plannedStart.text = _formatInputDate(intent!.plannedStartAt!.toLocal());
    }
    if (intent?.plannedEndAt != null) {
      _plannedEnd.text = _formatInputDate(intent!.plannedEndAt!.toLocal());
    } else if (intent?.plannedStartAt == null) {
      _plannedEnd.text = _formatInputDate(
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                aircraftId: widget.aircraftId,
                modifying: _sourceIntent != null,
                busy: _busy,
                onRunChecks: _saveAndCheck,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                ErrorPanel(error: _error!, onRetry: _saveAndCheck),
              ],
              const SizedBox(height: 18),
              TwoColumn(
                breakpoint: 1180,
                left: Column(
                  children: [
                    _MissionPanel(
                      aircraftId: widget.aircraftId,
                      missionName: _missionName,
                      summary: _summary,
                      useCase: _useCase,
                      routeSummary: _routeSummary,
                      plannedStart: _plannedStart,
                      plannedEnd: _plannedEnd,
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
                      onConformanceChanged: (value) {
                        setState(() => _conformanceRequired = value);
                      },
                    ),
                    const SizedBox(height: 18),
                    _VolumesPanel(
                      points: _volumePoints,
                      deconfliction: _deconfliction,
                      bufferMeters: _bufferMeters,
                      altitudeRef: _altitudeRef,
                      volumeType: _volumeType,
                      locked: editingLocked,
                      onLoadDefault: () {
                        setState(() => _volumePoints = _defaultVolumePoints());
                      },
                      onAddPoint: (point) {
                        setState(
                          () => _volumePoints = [..._volumePoints, point],
                        );
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
                    ),
                  ],
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.aircraftId,
    required this.modifying,
    required this.busy,
    required this.onRunChecks,
  });

  final String aircraftId;
  final bool modifying;
  final bool busy;
  final VoidCallback onRunChecks;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: busy ? null : onRunChecks,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
          label: const Text('Save & check'),
        ),
      ],
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
    required this.plannedStart,
    required this.plannedEnd,
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
    required this.onConformanceChanged,
  });

  final String aircraftId;
  final TextEditingController missionName;
  final TextEditingController summary;
  final TextEditingController useCase;
  final TextEditingController routeSummary;
  final TextEditingController plannedStart;
  final TextEditingController plannedEnd;
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
                _TextField(
                  controller: plannedStart,
                  label: 'Planned start',
                  enabled: !locked,
                  validator: _dateTime,
                ),
                _TextField(
                  controller: plannedEnd,
                  label: 'Planned end',
                  enabled: !locked,
                  validator: _dateTime,
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
    required this.locked,
    required this.onLoadDefault,
    required this.onAddPoint,
    required this.onRemovePoint,
    required this.onUndoPoint,
    required this.onAltitudeRefChanged,
    required this.onVolumeTypeChanged,
  });

  final List<LatLng> points;
  final DeconflictionResult? deconfliction;
  final TextEditingController bufferMeters;
  final String altitudeRef;
  final String volumeType;
  final bool locked;
  final VoidCallback onLoadDefault;
  final ValueChanged<LatLng> onAddPoint;
  final ValueChanged<int> onRemovePoint;
  final VoidCallback onUndoPoint;
  final ValueChanged<String?> onAltitudeRefChanged;
  final ValueChanged<String?> onVolumeTypeChanged;

  @override
  Widget build(BuildContext context) {
    final center = points.isEmpty
        ? const LatLng(35.4676, -97.5164)
        : points.first;
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
            tooltip: 'Reset polygon',
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
                    if (points.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: points,
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
                  label: points.length >= 3 ? 'ready' : 'draft',
                  icon: Icons.polyline_outlined,
                ),
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
                  const Text(
                    'Click the map to add points. Use point buttons to remove vertices.',
                    style: TextStyle(color: Color(0xFF7F90B6)),
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
              label: 'Buffer meters',
              keyboardType: TextInputType.number,
              enabled: !locked,
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
  final VoidCallback onAccept;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final accepted = intent?.status == 'accepted' || intent?.status == 'active';
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
            DetailLine(
              label: 'Activation',
              value: activatedIntent == null
                  ? checksClear
                        ? 'Ready after acceptance'
                        : 'Blocked until checks are clear'
                  : 'Active',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        busy || intent == null || !checksClear || accepted
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
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
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

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(displayEnum(option))),
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

String? _dateTime(String? value) {
  final required = _required(value);
  if (required != null) return required;
  return _parseInputDate(value!) == null
      ? 'Use yyyy-mm-dd hh:mm or ISO time'
      : null;
}

DateTime? _parseInputDate(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized)?.toUtc();
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _feetToMeters(double feet) => feet * 0.3048;
double _metersToFeet(double meters) => meters / 0.3048;

String _formatInputDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

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

List<LatLng> _defaultVolumePoints() {
  const centerLat = 35.4676;
  const centerLon = -97.5164;
  const delta = 0.004;
  return const [
    LatLng(centerLat - delta, centerLon - delta),
    LatLng(centerLat - delta, centerLon + delta),
    LatLng(centerLat + delta, centerLon + delta),
    LatLng(centerLat + delta, centerLon - delta),
  ];
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
