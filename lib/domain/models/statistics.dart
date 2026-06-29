import 'package:flutter/material.dart' show Color;

/// Total tracked time for one project within a range.
class ProjectTimeStat {
  const ProjectTimeStat({
    required this.projectId,
    required this.name,
    required this.color,
    required this.seconds,
  });

  final String projectId;
  final String name;
  final Color color;
  final int seconds;
}

/// A single bucket in the "time over time" chart.
class TimeBucket {
  const TimeBucket({required this.start, required this.seconds});
  final DateTime start;
  final int seconds;
}

/// One slice of the project-share donut.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.seconds,
    required this.color,
    required this.fraction,
  });

  final String label;
  final int seconds;
  final Color color;
  final double fraction;
}

/// Breakdown of where tracked time came from.
class SourceBreakdown {
  const SourceBreakdown({
    required this.timerSeconds,
    required this.additionSeconds,
    required this.removalSeconds,
  });

  final int timerSeconds;
  final int additionSeconds;
  final int removalSeconds;

  /// Net tracked total (never below zero for chart display).
  int get netSeconds {
    final net = timerSeconds + additionSeconds - removalSeconds;
    return net < 0 ? 0 : net;
  }
}

/// One of the longest completed timer segments.
class SessionStat {
  const SessionStat({
    required this.entryId,
    required this.projectId,
    required this.projectName,
    required this.color,
    required this.seconds,
    required this.startedAtUtc,
  });

  final String entryId;
  final String projectId;
  final String projectName;
  final Color color;
  final int seconds;
  final DateTime startedAtUtc;
}

/// Daily total for the activity heatmap (local day -> seconds).
class DayHeat {
  const DayHeat({required this.day, required this.seconds});
  final DateTime day;
  final int seconds;
}

/// Top-line summary metrics.
class StatsSummary {
  const StatsSummary({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.activeProjects,
    required this.runningProjects,
    required this.sessionCount,
    required this.longestSessionSeconds,
    required this.averagePerActiveDaySeconds,
    required this.netManualSeconds,
  });

  final int totalSeconds;
  final int todaySeconds;
  final int activeProjects;
  final int runningProjects;
  final int sessionCount;
  final int longestSessionSeconds;
  final int averagePerActiveDaySeconds;
  final int netManualSeconds;
}

/// The full computed statistics payload for a selected range.
class StatisticsResult {
  const StatisticsResult({
    required this.summary,
    required this.byProject,
    required this.overTime,
    required this.donut,
    required this.sources,
    required this.longestSessions,
    required this.heatmap,
    required this.sessionsPerDay,
  });

  final StatsSummary summary;
  final List<ProjectTimeStat> byProject;
  final List<TimeBucket> overTime;
  final List<DonutSlice> donut;
  final SourceBreakdown sources;
  final List<SessionStat> longestSessions;
  final List<DayHeat> heatmap;
  final List<TimeBucket> sessionsPerDay;

  bool get isEmpty => summary.totalSeconds == 0 && summary.sessionCount == 0;
}
