part of '../app_database.dart';

@DriftAccessor(tables: [TimerStates])
class TimerDao extends DatabaseAccessor<AppDatabase> with _$TimerDaoMixin {
  TimerDao(super.db);

  Stream<List<TimerState>> watchAll() => select(timerStates).watch();

  /// All timer states that are currently running.
  Stream<List<TimerState>> watchRunning() {
    return (select(timerStates)
          ..where((t) => t.status.equals(TimerStatus.running.name)))
        .watch();
  }

  Future<List<TimerState>> getRunning() {
    return (select(timerStates)
          ..where((t) => t.status.equals(TimerStatus.running.name)))
        .get();
  }

  Stream<TimerState?> watchByProject(String projectId) {
    return (select(timerStates)..where((t) => t.projectId.equals(projectId)))
        .watchSingleOrNull();
  }

  Future<TimerState?> getByProject(String projectId) {
    return (select(timerStates)..where((t) => t.projectId.equals(projectId)))
        .getSingleOrNull();
  }

  Future<void> upsert(TimerStatesCompanion companion) =>
      into(timerStates).insertOnConflictUpdate(companion);
}
