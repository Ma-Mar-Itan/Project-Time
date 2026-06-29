import 'package:flutter/material.dart' show Color;

import '../../core/utilities/clock.dart';
import '../../core/utilities/date_range_utils.dart';
import '../../core/utilities/time_entry_splitter.dart';
import '../../data/database/app_database.dart';
import '../models/enums.dart';
import '../models/statistics.dart';

/// Aggregates time entries into the statistics payload.
///
/// Allocation policy (documented for clarity):
/// - Timer segments are split across local calendar boundaries; only the
///   portion inside the selected range is counted.
/// - Manual additions/removals and initial time are allocated wholly to their
///   effective local day.
/// - Reset adjustments are excluded from tracked-time charts (they are an
///   accounting operation, not tracked work).
/// - Net chart values are floored at zero; gross timer/addition/removal totals
///   are preserved separately in the source breakdown.
class StatisticsService {
  const StatisticsService();

  /// Convenience that fetches the required data and computes the result.
  Future<StatisticsResult> computeFromDatabase({
    required AppDatabase db,
    required Clock clock,
    required LocalDateRange range,
    required BucketUnit bucketUnit,
    int maxDonutSlices = 6,
  }) async {
    final projects = await db.projectsDao.getAllIncludingArchived();
    final entries = await db.timeEntriesDao
        .getForStats(range.start.toUtc(), range.end.toUtc());
    final timerStates = await db.timerDao.getRunning();

    // Today's net is computed independently of the selected range.
    final nowLocal = clock.nowLocal();
    final todayRange = DateRangeUtils.resolve(StatRangeType.today,
        nowLocal: nowLocal);
    final todayEntries = await db.timeEntriesDao
        .getForStats(todayRange.start.toUtc(), todayRange.end.toUtc());
    final todaySeconds = _netInRange(todayEntries, todayRange);

    return compute(
      projects: projects,
      entries: entries,
      runningCount: timerStates.length,
      activeCount: projects.where((p) => !p.isArchived).length,
      range: range,
      bucketUnit: bucketUnit,
      todaySeconds: todaySeconds,
      nowLocal: nowLocal,
      maxDonutSlices: maxDonutSlices,
    );
  }

  /// Pure computation — fully unit-testable with no I/O.
  StatisticsResult compute({
    required List<Project> projects,
    required List<TimeEntry> entries,
    required int runningCount,
    required int activeCount,
    required LocalDateRange range,
    required BucketUnit bucketUnit,
    required int todaySeconds,
    required DateTime nowLocal,
    int maxDonutSlices = 6,
  }) {
    final projectsById = {for (final p in projects) p.id: p};

    final bucketTimer = <DateTime, int>{};
    final bucketAdd = <DateTime, int>{};
    final bucketRemove = <DateTime, int>{};
    final dayTimer = <DateTime, int>{};
    final dayAdd = <DateTime, int>{};
    final dayRemove = <DateTime, int>{};
    final projTimer = <String, int>{};
    final projAdd = <String, int>{};
    final projRemove = <String, int>{};
    final sessionsPerDay = <DateTime, int>{};

    var timerTotal = 0;
    var addTotal = 0;
    var removeTotal = 0;
    var sessionCount = 0;
    var longest = 0;
    final sessions = <SessionStat>[];

    for (final e in entries) {
      switch (e.entryType) {
        case EntryType.timerSegment:
          final s = e.startedAtUtc;
          final end = e.endedAtUtc;
          if (s == null || end == null) break;
          final sl = s.toLocal();
          final el = end.toLocal();
          final overlaps = sl.isBefore(range.end) && el.isAfter(range.start);
          if (!overlaps) break;

          final clampStart = sl.isBefore(range.start) ? range.start : sl;
          final clampEnd = el.isAfter(range.end) ? range.end : el;
          if (clampEnd.isAfter(clampStart)) {
            final secs = clampEnd.difference(clampStart).inSeconds;
            timerTotal += secs;
            projTimer[e.projectId] = (projTimer[e.projectId] ?? 0) + secs;
            _merge(bucketTimer,
                TimeEntrySplitter.splitByBucket(
                    startUtc: clampStart.toUtc(),
                    endUtc: clampEnd.toUtc(),
                    unit: bucketUnit));
            _merge(dayTimer,
                TimeEntrySplitter.splitByLocalDay(
                    startUtc: clampStart.toUtc(), endUtc: clampEnd.toUtc()));
          }
          sessionCount++;
          final full = e.signedDurationSeconds;
          if (full > longest) longest = full;
          final p = projectsById[e.projectId];
          sessions.add(SessionStat(
            entryId: e.id,
            projectId: e.projectId,
            projectName: p?.name ?? 'Project',
            color: Color(p?.colorValue ?? 0xFF1A73E8),
            seconds: full,
            startedAtUtc: s,
          ));
          final startDay = DateRangeUtils.startOfDay(sl);
          if (range.contains(sl)) {
            sessionsPerDay[startDay] = (sessionsPerDay[startDay] ?? 0) + 1;
          }
          break;

        case EntryType.manualAddition:
        case EntryType.initialTime:
        case EntryType.importedAdjustment:
          final eff = e.effectiveAtUtc.toLocal();
          if (!range.contains(eff)) break;
          final sec = e.signedDurationSeconds;
          if (sec <= 0) break; // imported adjustments may be negative; skip here
          addTotal += sec;
          projAdd[e.projectId] = (projAdd[e.projectId] ?? 0) + sec;
          final b = DateRangeUtils.bucketKey(eff, bucketUnit);
          bucketAdd[b] = (bucketAdd[b] ?? 0) + sec;
          final day = DateRangeUtils.startOfDay(eff);
          dayAdd[day] = (dayAdd[day] ?? 0) + sec;
          break;

        case EntryType.manualRemoval:
          final eff = e.effectiveAtUtc.toLocal();
          if (!range.contains(eff)) break;
          final sec = -e.signedDurationSeconds; // positive magnitude
          if (sec <= 0) break;
          removeTotal += sec;
          projRemove[e.projectId] = (projRemove[e.projectId] ?? 0) + sec;
          final b = DateRangeUtils.bucketKey(eff, bucketUnit);
          bucketRemove[b] = (bucketRemove[b] ?? 0) + sec;
          final day = DateRangeUtils.startOfDay(eff);
          dayRemove[day] = (dayRemove[day] ?? 0) + sec;
          break;

        case EntryType.resetAdjustment:
          break; // excluded from tracked charts
      }
    }

    // By project (net, floored at zero), sorted high to low.
    final byProject = <ProjectTimeStat>[];
    for (final p in projects) {
      if (p.isArchived) continue;
      final net = (projTimer[p.id] ?? 0) +
          (projAdd[p.id] ?? 0) -
          (projRemove[p.id] ?? 0);
      byProject.add(ProjectTimeStat(
        projectId: p.id,
        name: p.name,
        color: Color(p.colorValue),
        seconds: net < 0 ? 0 : net,
      ));
    }
    byProject.sort((a, b) => b.seconds.compareTo(a.seconds));

    // Over-time buckets (every bucket present; missing data => zero).
    final overTime = <TimeBucket>[];
    for (final b in DateRangeUtils.buckets(range, bucketUnit)) {
      final net =
          (bucketTimer[b] ?? 0) + (bucketAdd[b] ?? 0) - (bucketRemove[b] ?? 0);
      overTime.add(TimeBucket(start: b, seconds: net < 0 ? 0 : net));
    }

    // Sessions per day (count).
    final sessionsList = <TimeBucket>[];
    final sortedSessionDays = sessionsPerDay.keys.toList()..sort();
    for (final d in sortedSessionDays) {
      sessionsList.add(TimeBucket(start: d, seconds: sessionsPerDay[d]!));
    }

    // Heatmap (local-day net, last ~year within range).
    final heatStart = _maxDate(
        range.start, DateRangeUtils.startOfDay(nowLocal).subtract(
            const Duration(days: 371)));
    final heatmap = <DayHeat>[];
    var cursor = DateRangeUtils.startOfDay(heatStart);
    final heatEnd = range.end;
    while (cursor.isBefore(heatEnd)) {
      final net = (dayTimer[cursor] ?? 0) +
          (dayAdd[cursor] ?? 0) -
          (dayRemove[cursor] ?? 0);
      heatmap.add(DayHeat(day: cursor, seconds: net < 0 ? 0 : net));
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    // Donut (top N + Other).
    final donut = _buildDonut(byProject, maxDonutSlices);

    // Longest sessions (top 8 by full duration).
    sessions.sort((a, b) => b.seconds.compareTo(a.seconds));
    final longestSessions = sessions.take(8).toList();

    final netTracked = timerTotal + addTotal - removeTotal;
    final activeDays = _distinctActiveDays(dayTimer, dayAdd, dayRemove);
    final summary = StatsSummary(
      totalSeconds: netTracked < 0 ? 0 : netTracked,
      todaySeconds: todaySeconds,
      activeProjects: activeCount,
      runningProjects: runningCount,
      sessionCount: sessionCount,
      longestSessionSeconds: longest,
      averagePerActiveDaySeconds:
          activeDays == 0 ? 0 : ((netTracked < 0 ? 0 : netTracked) ~/ activeDays),
      netManualSeconds: addTotal - removeTotal,
    );

    return StatisticsResult(
      summary: summary,
      byProject: byProject,
      overTime: overTime,
      donut: donut,
      sources: SourceBreakdown(
        timerSeconds: timerTotal,
        additionSeconds: addTotal,
        removalSeconds: removeTotal,
      ),
      longestSessions: longestSessions,
      heatmap: heatmap,
      sessionsPerDay: sessionsList,
    );
  }

  // --- helpers ---

  /// Public net-seconds-in-range helper (used for per-project summary cards).
  static int netInRange(List<TimeEntry> entries, LocalDateRange range) =>
      _netInRange(entries, range);

  static int _netInRange(List<TimeEntry> entries, LocalDateRange range) {
    var timer = 0, add = 0, remove = 0;
    for (final e in entries) {
      switch (e.entryType) {
        case EntryType.timerSegment:
          final s = e.startedAtUtc, end = e.endedAtUtc;
          if (s == null || end == null) break;
          final sl = s.toLocal(), el = end.toLocal();
          final cs = sl.isBefore(range.start) ? range.start : sl;
          final ce = el.isAfter(range.end) ? range.end : el;
          if (ce.isAfter(cs)) timer += ce.difference(cs).inSeconds;
          break;
        case EntryType.manualAddition:
        case EntryType.initialTime:
        case EntryType.importedAdjustment:
          if (range.contains(e.effectiveAtUtc.toLocal()) &&
              e.signedDurationSeconds > 0) {
            add += e.signedDurationSeconds;
          }
          break;
        case EntryType.manualRemoval:
          if (range.contains(e.effectiveAtUtc.toLocal())) {
            remove += -e.signedDurationSeconds;
          }
          break;
        case EntryType.resetAdjustment:
          break;
      }
    }
    final net = timer + add - remove;
    return net < 0 ? 0 : net;
  }

  static void _merge(Map<DateTime, int> target, Map<DateTime, int> source) {
    source.forEach((k, v) => target[k] = (target[k] ?? 0) + v);
  }

  static DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static int _distinctActiveDays(
    Map<DateTime, int> timer,
    Map<DateTime, int> add,
    Map<DateTime, int> remove,
  ) {
    final days = <DateTime>{...timer.keys, ...add.keys, ...remove.keys};
    var count = 0;
    for (final d in days) {
      final net = (timer[d] ?? 0) + (add[d] ?? 0) - (remove[d] ?? 0);
      if (net > 0) count++;
    }
    return count;
  }

  static List<DonutSlice> _buildDonut(
      List<ProjectTimeStat> byProject, int maxSlices) {
    final positive = byProject.where((p) => p.seconds > 0).toList();
    if (positive.isEmpty) return const [];
    final total = positive.fold<int>(0, (sum, p) => sum + p.seconds);
    if (total == 0) return const [];

    final slices = <DonutSlice>[];
    final head = positive.take(maxSlices - 1).toList();
    final tail = positive.skip(maxSlices - 1).toList();
    for (final p in head) {
      slices.add(DonutSlice(
        label: p.name,
        seconds: p.seconds,
        color: p.color,
        fraction: p.seconds / total,
      ));
    }
    if (tail.isNotEmpty) {
      final otherSeconds = tail.fold<int>(0, (sum, p) => sum + p.seconds);
      slices.add(DonutSlice(
        label: 'Other',
        seconds: otherSeconds,
        color: const Color(0xFF9AA0A6),
        fraction: otherSeconds / total,
      ));
    }
    return slices;
  }
}
