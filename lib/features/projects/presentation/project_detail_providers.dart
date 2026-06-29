import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utilities/date_range_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/services/statistics_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/project_providers.dart';

/// Per-project summary used on the detail screen.
class ProjectDetailStats {
  const ProjectDetailStats({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.monthSeconds,
    required this.allTimeSeconds,
    required this.segmentCount,
    required this.manualCount,
    required this.longestSessionSeconds,
    required this.averageSessionSeconds,
  });

  final int todaySeconds;
  final int weekSeconds;
  final int monthSeconds;
  final int allTimeSeconds;
  final int segmentCount;
  final int manualCount;
  final int longestSessionSeconds;
  final int averageSessionSeconds;
}

/// Recomputes when the project's totals change.
final projectDetailStatsProvider =
    FutureProvider.family<ProjectDetailStats, String>((ref, projectId) async {
  ref.watch(projectTotalsProvider); // re-run on data change
  final db = ref.read(databaseProvider);
  final clock = ref.read(clockProvider);
  final entries = await db.timeEntriesDao.getByProject(projectId);
  final nowLocal = clock.nowLocal();

  LocalDateRange range(StatRangeType t) =>
      DateRangeUtils.resolve(t, nowLocal: nowLocal);

  final segments =
      entries.where((e) => e.entryType == EntryType.timerSegment).toList();
  final manual = entries
      .where((e) =>
          e.entryType == EntryType.manualAddition ||
          e.entryType == EntryType.manualRemoval)
      .length;

  var longest = 0;
  var segmentTotal = 0;
  for (final s in segments) {
    if (s.signedDurationSeconds > longest) longest = s.signedDurationSeconds;
    segmentTotal += s.signedDurationSeconds;
  }
  final average = segments.isEmpty ? 0 : segmentTotal ~/ segments.length;

  return ProjectDetailStats(
    todaySeconds: StatisticsService.netInRange(entries, range(StatRangeType.today)),
    weekSeconds: StatisticsService.netInRange(entries, range(StatRangeType.week)),
    monthSeconds:
        StatisticsService.netInRange(entries, range(StatRangeType.month)),
    allTimeSeconds:
        StatisticsService.netInRange(entries, range(StatRangeType.all)),
    segmentCount: segments.length,
    manualCount: manual,
    longestSessionSeconds: longest,
    averageSessionSeconds: average,
  );
});

/// This project's activity events, newest first.
final projectEventsProvider =
    StreamProvider.family<List<ActivityEvent>, String>((ref, projectId) {
  return ref.read(databaseProvider).eventsDao.watchByProject(projectId);
});
