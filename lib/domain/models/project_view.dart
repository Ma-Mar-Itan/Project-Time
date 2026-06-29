import 'package:flutter/material.dart' show Color;

import '../../data/database/app_database.dart';
import 'enums.dart';

/// A read-model that combines a [Project] row, its current [TimerStatus] and
/// its stored total seconds. The live total is computed on demand against a
/// clock instant, never accumulated.
class ProjectView {
  const ProjectView({
    required this.project,
    required this.status,
    required this.runningStartedAtUtc,
    required this.storedSeconds,
  });

  final Project project;
  final TimerStatus status;
  final DateTime? runningStartedAtUtc;

  /// Sum of every time entry for the project (segments + manual + reset +
  /// initial). This is the project's stored total, excluding any live segment.
  final int storedSeconds;

  String get id => project.id;
  String get name => project.name;
  Color get color => Color(project.colorValue);
  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isStopped => status == TimerStatus.stopped;

  /// Seconds currently elapsing in the live running segment (0 if not running).
  int liveSegmentSeconds(DateTime nowUtc) {
    if (status != TimerStatus.running || runningStartedAtUtc == null) return 0;
    final seconds = nowUtc.difference(runningStartedAtUtc!).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  /// Total tracked time as of [nowUtc], floored at zero for display.
  Duration totalAt(DateTime nowUtc) {
    final seconds = storedSeconds + liveSegmentSeconds(nowUtc);
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }

  /// Estimated monetary value for the current total, in minor currency units
  /// (e.g. cents), or null when no hourly rate is set.
  int? estimatedValueMinorUnits(DateTime nowUtc) {
    final rate = project.hourlyRateMinorUnits;
    if (rate == null) return null;
    final hours = totalAt(nowUtc).inSeconds / 3600.0;
    return (hours * rate).round();
  }
}
