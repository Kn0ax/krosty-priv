import 'package:flutter/material.dart';
import 'package:krosty/services/shared_timer_service.dart';

/// A widget that displays a timer representing the time since the given start time.
/// Uses a shared timer service to keep all uptime displays synchronized.
class Uptime extends StatefulWidget {
  final String startTime;
  final TextStyle? style;

  const Uptime({super.key, required this.startTime, this.style});

  @override
  State<Uptime> createState() => _UptimeState();
}

class _UptimeState extends State<Uptime> {
  late final SharedTimerService _timerService;

  @override
  void initState() {
    super.initState();
    _timerService = SharedTimerService.instance;
    _timerService.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely parse the start time, return empty if invalid
    final startTime = DateTime.tryParse(widget.startTime);
    if (startTime == null) {
      return Text(
        '0:00:00',
        style: widget.style?.copyWith(
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      );
    }

    return Text(
      _timerService.currentTime
          .difference(startTime)
          .toString()
          .split('.')[0],
      style: widget.style?.copyWith(
        fontFeatures: [const FontFeature.tabularFigures()],
      ),
    );
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTick);
    super.dispose();
  }
}
