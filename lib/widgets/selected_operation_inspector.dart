import 'package:flutter/material.dart';

import '../models/aero_arc_models.dart';
import 'dashboard_ui.dart';
import 'operational_selection.dart';

/// Read-only contextual state; planned commands are not observed execution.
class SelectedOperationInspector extends StatelessWidget {
  const SelectedOperationInspector({
    super.key,
    required this.aircraftId,
    required this.intent,
    required this.state,
    required this.conformance,
    required this.mapView,
    required this.onClose,
    this.error,
  });
  final String aircraftId;
  final OperationalIntent? intent;
  final AircraftLiveState? state;
  final ConformanceSummary? conformance;
  final AircraftMapView? mapView;
  final VoidCallback onClose;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final telemetry = state?.telemetry;
    final mission = mapView?.validatedMission;
    final boundMission =
        intent != null &&
            mission?.intentId == intent!.id &&
            mission?.intentVersion == intent!.version
        ? mission
        : null;
    final name = intent?.name.trim().isNotEmpty == true
        ? intent!.name
        : operationName(context, intent?.id ?? '', aircraftId);
    String value(num? n, String unit) =>
        n == null ? 'Unknown' : '${n.toStringAsFixed(1)} $unit';
    Widget sample(
      String label,
      TelemetryGroup? group,
      List<Widget> fields,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '$label · ${displayEnum(group?.status ?? 'missing')} · ${formatDate(group?.recordedAt)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF8797AB)),
        ),
        ...fields,
      ],
    );
    return Panel(
      title: name,
      trailing: IconButton(
        tooltip: 'Close inspector',
        onPressed: onClose,
        icon: const Icon(Icons.close, size: 18),
      ),
      child: SizedBox(
        height: 460,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '$aircraftId · ${intent == null ? 'No unambiguous operation selected' : 'Intent ${shortOperationalId(intent!.id)} · v${intent!.version}'}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
            _section('MISSION'),
            DetailLine(
              label: 'Operation',
              value: intent == null ? 'Unknown' : displayEnum(intent!.status),
            ),
            DetailLine(
              label: 'Plan',
              value: boundMission == null
                  ? 'Not available for this operation'
                  : '${boundMission.items.length} mission items · v${boundMission.version}',
            ),
            const DetailLine(
              label: 'Progress / next action',
              value: 'Not reported',
            ),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: Color(0xFFE4A100), fontSize: 11),
              ),
            _section('COMMANDED'),
            Text(
              boundMission == null
                  ? 'No matching commanded mission available.'
                  : 'Stored mission plan available. Delivery acknowledgment and execution are not reported here.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'A stored plan is not proof of aircraft execution.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
            _section('OBSERVED'),
            sample('Position', telemetry?.position, [
              DetailLine(
                label: 'Altitude MSL',
                value: value(telemetry?.position?.altitudeMslM, 'm'),
              ),
              DetailLine(
                label: 'Ground speed',
                value: value(telemetry?.position?.groundspeedMps, 'm/s'),
              ),
              DetailLine(
                label: 'Heading',
                value: value(telemetry?.position?.headingDeg, '°'),
              ),
            ]),
            sample('Battery', telemetry?.battery, [
              DetailLine(
                label: 'Remaining',
                value: value(telemetry?.battery?.remainingPct, '%'),
              ),
            ]),
            sample('GPS', telemetry?.gps, [
              DetailLine(
                label: 'Fix',
                value: telemetry?.gps?.fixType ?? 'Unknown',
              ),
              DetailLine(
                label: 'Satellites',
                value:
                    telemetry?.gps?.satellitesVisible?.toString() ?? 'Unknown',
              ),
            ]),
            sample('Flight', telemetry?.hud, [
              DetailLine(
                label: 'Vertical speed',
                value: value(telemetry?.hud?.climbRateMps, 'm/s'),
              ),
            ]),
            _section('CONFORMANCE'),
            DetailLine(
              label: 'Condition',
              value: conformance?.condition ?? conformance?.status ?? 'Unknown',
            ),
            DetailLine(
              label: 'Monitoring',
              value: conformance?.monitoringStatus ?? 'Unknown',
            ),
            DetailLine(
              label: 'Recording',
              value: conformance?.recordingStatus ?? 'Unknown',
            ),
            for (final v
                in conformance?.activeViolations ?? <ConformanceViolation>[])
              DetailLine(
                label: displayEnum(v.type),
                value:
                    '${displayEnum(v.phase)}${v.type == 'temporal_deviation' || v.worstDeviationM == null ? '' : ' · worst ${v.worstDeviationM!.toStringAsFixed(1)} m'}',
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/conformance'),
              child: const Text('Review conformance evidence'),
            ),
            _section('AUTHORITY'),
            const Text(
              'Intent metadata—not a clearance or authorization to act.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
            DetailLine(
              label: 'Intent state',
              value: intent?.status ?? 'Unknown',
            ),
            DetailLine(
              label: 'Authorization path',
              value: intent?.authorizationPath.isNotEmpty == true
                  ? intent!.authorizationPath
                  : 'Not reported',
            ),
            DetailLine(
              label: 'Generation',
              value:
                  conformance?.assignmentGeneration?.toString() ??
                  'Not reported',
            ),
            DetailLine(
              label: 'Planned start',
              value: formatDate(intent?.plannedStartAt),
            ),
            DetailLine(
              label: 'Planned end',
              value: formatDate(intent?.plannedEndAt),
            ),
            _section('CONNECTIVITY'),
            DetailLine(
              label: 'Agent connection',
              value: state?.connection.status ?? 'Unknown',
            ),
            DetailLine(
              label: 'Last heartbeat',
              value: formatDate(state?.connection.lastHeartbeatAt),
            ),
            DetailLine(
              label: 'Relay placement',
              value: state?.connection.relayId ?? 'Unknown',
            ),
            const Text(
              'Placement identifies the relay; independent relay health is not reported.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
            _section('ALERTS'),
            Text(
              conformance == null
                  ? 'Conformance alerts unavailable.'
                  : '${conformance!.activeViolationCount} active findings · ${conformance!.alertCount} reported alerts',
            ),
            const Text(
              'Fleet-wide alerts remain visible outside this inspector.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8797AB)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/aircraft/${Uri.encodeComponent(aircraftId)}/map'),
              child: const Text('Open mission & flight controls'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _section(String title) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1,
      color: Color(0xFF16C8E0),
    ),
  ),
);
