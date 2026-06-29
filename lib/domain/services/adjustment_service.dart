import 'package:drift/drift.dart';

import '../../core/utilities/clock.dart';
import '../../data/database/app_database.dart';
import '../models/enums.dart';
import 'id_generator.dart';

/// Raised when a manual adjustment would violate an invariant (e.g. removing
/// more time than a project has).
class AdjustmentException implements Exception {
  AdjustmentException(this.message);
  final String message;
  @override
  String toString() => 'AdjustmentException: $message';
}

/// Handles manual time additions/removals and project resets. Every change is
/// stored as a separate, immutable signed [TimeEntry]; project totals are never
/// overwritten directly.
class AdjustmentService {
  AdjustmentService({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator ids,
  })  : _db = db,
        _clock = clock,
        _ids = ids;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  /// Current total seconds including any live running segment.
  Future<int> currentTotalSeconds(String projectId) async {
    final stored = await _db.timeEntriesDao.completedSecondsForProject(projectId);
    final state = await _db.timerDao.getByProject(projectId);
    var live = 0;
    if (state != null &&
        state.status == TimerStatus.running &&
        state.runningStartedAtUtc != null) {
      final seconds =
          _clock.nowUtc().difference(state.runningStartedAtUtc!).inSeconds;
      if (seconds > 0) live = seconds;
    }
    final total = stored + live;
    return total < 0 ? 0 : total;
  }

  /// Adds positive [amount] of manual time.
  Future<void> addManualTime(
    String projectId, {
    required Duration amount,
    String? note,
    DateTime? effectiveAtUtc,
  }) async {
    if (amount.inSeconds <= 0) {
      throw AdjustmentException('Duration must be greater than zero.');
    }
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      final effective = (effectiveAtUtc ?? now).toUtc();
      await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
        id: Value(_ids.newId()),
        projectId: Value(projectId),
        entryType: const Value(EntryType.manualAddition),
        signedDurationSeconds: Value(amount.inSeconds),
        effectiveAtUtc: Value(effective),
        note: Value(note),
        createdAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.manualAdded, now,
          durationSeconds: amount.inSeconds, note: note);
      await _touch(projectId, now);
    });
  }

  /// Removes positive [amount] of manual time. Throws if it would push the
  /// total below zero.
  Future<void> removeManualTime(
    String projectId, {
    required Duration amount,
    String? note,
    DateTime? effectiveAtUtc,
  }) async {
    if (amount.inSeconds <= 0) {
      throw AdjustmentException('Duration must be greater than zero.');
    }
    await _db.transaction(() async {
      final total = await currentTotalSeconds(projectId);
      if (amount.inSeconds > total) {
        throw AdjustmentException(
            'Cannot remove more than the current total time.');
      }
      final now = _clock.nowUtc();
      final effective = (effectiveAtUtc ?? now).toUtc();
      await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
        id: Value(_ids.newId()),
        projectId: Value(projectId),
        entryType: const Value(EntryType.manualRemoval),
        signedDurationSeconds: Value(-amount.inSeconds),
        effectiveAtUtc: Value(effective),
        note: Value(note),
        createdAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.manualRemoved, now,
          durationSeconds: -amount.inSeconds, note: note);
      await _touch(projectId, now);
    });
  }

  /// Resets a project's visible total to zero while preserving history. Stops a
  /// running timer as part of the same transaction and writes a negative
  /// reset adjustment equal to the current total.
  Future<void> resetTotal(String projectId, {String? reason}) async {
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      final state = await _db.timerDao.getByProject(projectId);

      // Finalize a running segment so it is counted before resetting.
      final runningStart = state?.runningStartedAtUtc;
      if (state != null &&
          state.status == TimerStatus.running &&
          runningStart != null) {
        final seconds = now.difference(runningStart).inSeconds;
        if (seconds > 0) {
          await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
            id: Value(_ids.newId()),
            projectId: Value(projectId),
            entryType: const Value(EntryType.timerSegment),
            signedDurationSeconds: Value(seconds),
            startedAtUtc: Value(runningStart),
            endedAtUtc: Value(now),
            effectiveAtUtc: Value(runningStart),
            createdAtUtc: Value(now),
          ));
        }
      }

      final total =
          await _db.timeEntriesDao.completedSecondsForProject(projectId);
      if (total != 0) {
        await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
          id: Value(_ids.newId()),
          projectId: Value(projectId),
          entryType: const Value(EntryType.resetAdjustment),
          signedDurationSeconds: Value(-total),
          effectiveAtUtc: Value(now),
          note: Value(reason),
          createdAtUtc: Value(now),
        ));
      }

      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(projectId),
        status: const Value(TimerStatus.stopped),
        runningStartedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.projectReset, now,
          durationSeconds: total, note: reason);
      await _touch(projectId, now);
    });
  }

  Future<void> _logEvent(
    String projectId,
    EventType type,
    DateTime now, {
    int? durationSeconds,
    String? note,
  }) async {
    await _db.eventsDao.insertEvent(ActivityEventsCompanion(
      id: Value(_ids.newId()),
      projectId: Value(projectId),
      eventType: Value(type),
      occurredAtUtc: Value(now),
      durationSeconds: Value(durationSeconds),
      note: Value(note),
    ));
  }

  Future<void> _touch(String projectId, DateTime now) async {
    await _db.projectsDao.updateProject(ProjectsCompanion(
      id: Value(projectId),
      lastActivityAtUtc: Value(now),
      updatedAtUtc: Value(now),
    ));
  }
}
