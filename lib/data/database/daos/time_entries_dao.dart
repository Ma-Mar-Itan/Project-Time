part of '../app_database.dart';

@DriftAccessor(tables: [TimeEntries])
class TimeEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$TimeEntriesDaoMixin {
  TimeEntriesDao(super.db);

  Future<void> insertEntry(TimeEntriesCompanion companion) =>
      into(timeEntries).insert(companion);

  Stream<List<TimeEntry>> watchByProject(String projectId) {
    return (select(timeEntries)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.effectiveAtUtc)]))
        .watch();
  }

  Future<List<TimeEntry>> getByProject(String projectId) {
    return (select(timeEntries)
          ..where((t) => t.projectId.equals(projectId)))
        .get();
  }

  Stream<List<TimeEntry>> watchAll() => select(timeEntries).watch();

  Future<List<TimeEntry>> getAll() => select(timeEntries).get();

  /// Entries whose effective instant falls in [startUtc, endUtc).
  Future<List<TimeEntry>> getInEffectiveRange(
      DateTime startUtc, DateTime endUtc) {
    return (select(timeEntries)
          ..where((t) =>
              t.effectiveAtUtc.isBiggerOrEqualValue(startUtc) &
              t.effectiveAtUtc.isSmallerThanValue(endUtc)))
        .get();
  }

  /// Entries that overlap the local range [startUtc, endUtc) — including timer
  /// segments that started before the range but ended inside it.
  Future<List<TimeEntry>> getForStats(DateTime startUtc, DateTime endUtc) {
    return (select(timeEntries)
          ..where((t) =>
              t.effectiveAtUtc.isSmallerThanValue(endUtc) &
              ((t.endedAtUtc.isNotNull() &
                      t.endedAtUtc.isBiggerThanValue(startUtc)) |
                  (t.endedAtUtc.isNull() &
                      t.effectiveAtUtc.isBiggerOrEqualValue(startUtc)))))
        .get();
  }

  /// Sum of all signed seconds for a project (its stored total, excluding the
  /// live running segment). Backed by the project index.
  Future<int> completedSecondsForProject(String projectId) async {
    final sumExp = timeEntries.signedDurationSeconds.sum();
    final q = selectOnly(timeEntries)
      ..addColumns([sumExp])
      ..where(timeEntries.projectId.equals(projectId));
    final row = await q.getSingle();
    return row.read(sumExp) ?? 0;
  }

  /// Reactive map of projectId -> stored total seconds (sum of all entries).
  /// Backed by the project index; recomputed by SQLite, not in Dart.
  Stream<Map<String, int>> watchProjectTotals() {
    final total = timeEntries.signedDurationSeconds.sum();
    final query = selectOnly(timeEntries)
      ..addColumns([timeEntries.projectId, total])
      ..groupBy([timeEntries.projectId]);
    return query.watch().map((rows) => {
          for (final r in rows)
            r.read(timeEntries.projectId)!: r.read(total) ?? 0,
        });
  }

  Future<void> deleteByProject(String projectId) {
    return (delete(timeEntries)..where((t) => t.projectId.equals(projectId)))
        .go();
  }
}
