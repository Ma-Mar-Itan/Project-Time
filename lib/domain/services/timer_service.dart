import 'package:drift/drift.dart';

import '../../core/utilities/clock.dart';
import '../../data/database/app_database.dart';
import '../models/enums.dart';
import 'id_generator.dart';

/// Transactional timer state machine. The authoritative state lives in
/// `timer_states` (status + runningStartedAtUtc) and completed segments in
/// `time_entries`. The UI ticker is purely cosmetic.
class TimerService {
  TimerService({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator ids,
  })  : _db = db,
        _clock = clock,
        _ids = ids;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  /// Starts a stopped/paused project's timer. No-op if already running.
  Future<void> start(String projectId) async {
    await _db.transaction(() async {
      final state = await _db.timerDao.getByProject(projectId);
      if (state != null && state.status == TimerStatus.running) {
        return; // Guard against double-start / already running.
      }
      final now = _clock.nowUtc();
      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(projectId),
        status: const Value(TimerStatus.running),
        runningStartedAtUtc: Value(now),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.timerStarted, now);
      await _touchProject(projectId, now);
    });
  }

  /// Pauses a running timer, finalizing the live segment. No-op if not running.
  Future<void> pause(String projectId) async {
    await _db.transaction(() async {
      final state = await _db.timerDao.getByProject(projectId);
      if (state == null || state.status != TimerStatus.running) return;
      final now = _clock.nowUtc();
      await _finalizeSegment(state, now);
      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(projectId),
        status: const Value(TimerStatus.paused),
        runningStartedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.timerPaused, now);
      await _touchProject(projectId, now);
    });
  }

  /// Resumes a paused timer as a new continuous segment. No-op if running.
  Future<void> resume(String projectId) async {
    await _db.transaction(() async {
      final state = await _db.timerDao.getByProject(projectId);
      if (state != null && state.status == TimerStatus.running) return;
      final now = _clock.nowUtc();
      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(projectId),
        status: const Value(TimerStatus.running),
        runningStartedAtUtc: Value(now),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.timerResumed, now);
      await _touchProject(projectId, now);
    });
  }

  /// Stops a timer. Finalizes the live segment if running. No-op if stopped.
  Future<void> stop(String projectId) async {
    await _db.transaction(() async {
      final state = await _db.timerDao.getByProject(projectId);
      if (state == null || state.status == TimerStatus.stopped) return;
      final now = _clock.nowUtc();
      if (state.status == TimerStatus.running) {
        await _finalizeSegment(state, now);
      }
      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(projectId),
        status: const Value(TimerStatus.stopped),
        runningStartedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(projectId, EventType.timerStopped, now);
      await _touchProject(projectId, now);
    });
  }

  /// Pauses every running timer in a single transaction.
  Future<int> pauseAll() async {
    return _db.transaction(() async {
      final running = await _db.timerDao.getRunning();
      final now = _clock.nowUtc();
      for (final state in running) {
        await _finalizeSegment(state, now);
        await _db.timerDao.upsert(TimerStatesCompanion(
          projectId: Value(state.projectId),
          status: const Value(TimerStatus.paused),
          runningStartedAtUtc: const Value(null),
          updatedAtUtc: Value(now),
        ));
        await _logEvent(state.projectId, EventType.timerPaused, now);
        await _touchProject(state.projectId, now);
      }
      return running.length;
    });
  }

  /// Inserts a completed timer segment for the elapsed live interval. Guards
  /// against zero/negative intervals (clock skew).
  Future<void> _finalizeSegment(TimerState state, DateTime now) async {
    final start = state.runningStartedAtUtc;
    if (start == null) return;
    final seconds = now.difference(start).inSeconds;
    if (seconds <= 0) return; // Never store empty or negative segments.
    await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
      id: Value(_ids.newId()),
      projectId: Value(state.projectId),
      entryType: const Value(EntryType.timerSegment),
      signedDurationSeconds: Value(seconds),
      startedAtUtc: Value(start),
      endedAtUtc: Value(now),
      // Segments are allocated to their start instant for daily stats; the
      // splitter later distributes across day boundaries.
      effectiveAtUtc: Value(start),
      createdAtUtc: Value(now),
    ));
    await _logEvent(
      state.projectId,
      EventType.segmentCompleted,
      now,
      durationSeconds: seconds,
    );
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

  Future<void> _touchProject(String projectId, DateTime now) async {
    await _db.projectsDao.updateProject(ProjectsCompanion(
      id: Value(projectId),
      lastActivityAtUtc: Value(now),
      updatedAtUtc: Value(now),
    ));
  }
}
