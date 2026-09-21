import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Interpolates only the map presentation between received position samples.
/// Telemetry, breadcrumbs, and conformance continue to use the actual samples.
class AnimatedAircraftPosition extends StatefulWidget {
  const AnimatedAircraftPosition({
    super.key,
    required this.point,
    required this.heading,
    required this.recordedAt,
    required this.fresh,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });

  final LatLng point;
  final double heading;
  final DateTime? recordedAt;
  final bool fresh;
  final Duration duration;
  final Widget Function(BuildContext, LatLng, double) builder;

  @override
  State<AnimatedAircraftPosition> createState() =>
      _AnimatedAircraftPositionState();
}

class _AnimatedAircraftPositionState extends State<AnimatedAircraftPosition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late LatLng _from;
  late double _headingFrom;

  @override
  void initState() {
    super.initState();
    _from = widget.point;
    _headingFrom = widget.heading;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedAircraftPosition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousPoint = interpolateMapPosition(
      _from,
      oldWidget.point,
      _controller.value,
    );
    final previousHeading =
        _headingFrom +
        shortestAngleDelta(_headingFrom, oldWidget.heading) * _controller.value;
    final gap = widget.recordedAt?.difference(
      oldWidget.recordedAt ?? widget.recordedAt!,
    );
    final canAnimate =
        widget.fresh &&
        oldWidget.fresh &&
        gap != null &&
        gap > Duration.zero &&
        gap <= const Duration(seconds: 10) &&
        !MediaQuery.disableAnimationsOf(context);
    if (oldWidget.point == widget.point &&
        oldWidget.heading == widget.heading &&
        widget.fresh == oldWidget.fresh) {
      return;
    }
    _controller.duration = widget.duration;
    if (canAnimate) {
      _from = previousPoint;
      _headingFrom = previousHeading;
      _controller.forward(from: 0);
    } else {
      _controller.stop();
      _from = widget.point;
      _headingFrom = widget.heading;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = MediaQuery.disableAnimationsOf(context)
          ? 1.0
          : _controller.value;
      return widget.builder(
        context,
        interpolateMapPosition(_from, widget.point, t),
        (_headingFrom + shortestAngleDelta(_headingFrom, widget.heading) * t) %
            360,
      );
    },
  );
}

/// Returns the shortest signed rotation, including across north/the dateline.
double shortestAngleDelta(double from, double to) =>
    (to - from + 540) % 360 - 180;

/// Interpolates coordinates without taking the long route around the dateline.
LatLng interpolateMapPosition(LatLng from, LatLng to, double t) => LatLng(
  from.latitude + (to.latitude - from.latitude) * t,
  (from.longitude +
              shortestAngleDelta(from.longitude, to.longitude) * t +
              540) %
          360 -
      180,
);
