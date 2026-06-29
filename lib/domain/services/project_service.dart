import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/utilities/clock.dart';
import '../../data/database/app_database.dart';
import '../models/enums.dart';
import 'id_generator.dart';

/// Input payload for creating or editing a project.
class ProjectInput {
  ProjectInput({
    required this.name,
    this.description,
    this.clientOrCategory,
    this.notes,
    required this.colorValue,
    this.hourlyRateMinorUnits,
    this.currencyCode,
    this.deadlineUtc,
    this.initialTime = Duration.zero,
    this.isArchived = false,
  });

  final String name;
  final String? description;
  final String? clientOrCategory;
  final String? notes;
  final int colorValue;
  final int? hourlyRateMinorUnits;
  final String? currencyCode;
  final DateTime? deadlineUtc;
  final Duration initialTime;
  final bool isArchived;
}

/// Lifecycle operations for projects (create / edit / archive / delete).
class ProjectService {
  ProjectService({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator ids,
  })  : _db = db,
        _clock = clock,
        _ids = ids;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  Future<String> create(ProjectInput input) async {
    final id = _ids.newId();
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      await _db.projectsDao.insertProject(ProjectsCompanion.insert(
        id: id,
        name: input.name.trim(),
        description: Value(_trimOrNull(input.description)),
        clientOrCategory: Value(_trimOrNull(input.clientOrCategory)),
        notes: Value(_trimOrNull(input.notes)),
        colorValue: input.colorValue,
        hourlyRateMinorUnits: Value(input.hourlyRateMinorUnits),
        currencyCode: Value(input.currencyCode),
        deadlineUtc: Value(input.deadlineUtc),
        createdAtUtc: now,
        updatedAtUtc: now,
        lastActivityAtUtc: Value(now),
        isArchived: Value(input.isArchived),
        archivedAtUtc: Value(input.isArchived ? now : null),
      ));
      await _db.timerDao.upsert(TimerStatesCompanion(
        projectId: Value(id),
        status: const Value(TimerStatus.stopped),
        runningStartedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
      ));
      if (input.initialTime.inSeconds > 0) {
        await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
          id: Value(_ids.newId()),
          projectId: Value(id),
          entryType: const Value(EntryType.initialTime),
          signedDurationSeconds: Value(input.initialTime.inSeconds),
          effectiveAtUtc: Value(now),
          note: const Value('Initial time'),
          createdAtUtc: Value(now),
        ));
      }
      await _logEvent(id, EventType.projectCreated, now);
    });
    return id;
  }

  Future<void> edit(String id, ProjectInput input) async {
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      await _db.projectsDao.updateProject(ProjectsCompanion(
        id: Value(id),
        name: Value(input.name.trim()),
        description: Value(_trimOrNull(input.description)),
        clientOrCategory: Value(_trimOrNull(input.clientOrCategory)),
        notes: Value(_trimOrNull(input.notes)),
        colorValue: Value(input.colorValue),
        hourlyRateMinorUnits: Value(input.hourlyRateMinorUnits),
        currencyCode: Value(input.currencyCode),
        deadlineUtc: Value(input.deadlineUtc),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(id, EventType.projectEdited, now);
    });
  }

  /// Archives a project, stopping a running timer first (within the same txn).
  Future<void> archive(String id) async {
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      await _stopIfRunning(id, now);
      await _db.projectsDao.updateProject(ProjectsCompanion(
        id: Value(id),
        isArchived: const Value(true),
        archivedAtUtc: Value(now),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(id, EventType.projectArchived, now);
    });
  }

  Future<void> restore(String id) async {
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      await _db.projectsDao.updateProject(ProjectsCompanion(
        id: Value(id),
        isArchived: const Value(false),
        archivedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
      ));
      await _logEvent(id, EventType.projectRestored, now);
    });
  }

  /// Permanently deletes a project and all of its records. A global audit
  /// event (with a null projectId) is retained in the history.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final now = _clock.nowUtc();
      final project = await _db.projectsDao.getById(id);
      final name = project?.name ?? 'Project';

      // Global audit event survives the deletion (projectId stays null).
      await _db.eventsDao.insertEvent(ActivityEventsCompanion(
        id: Value(_ids.newId()),
        projectId: const Value(null),
        eventType: const Value(EventType.projectDeleted),
        occurredAtUtc: Value(now),
        note: Value(name),
        metadataJson: Value(jsonEncode({'projectName': name, 'projectId': id})),
      ));

      // Remove project-scoped records. Timer state and time entries are also
      // covered by ON DELETE CASCADE; we delete events explicitly because they
      // use ON DELETE SET NULL to preserve the audit row above.
      await _db.eventsDao.deleteByProject(id);
      await _db.timeEntriesDao.deleteByProject(id);
      await (_db.delete(_db.timerStates)
            ..where((t) => t.projectId.equals(id)))
          .go();
      await (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> _stopIfRunning(String id, DateTime now) async {
    final state = await _db.timerDao.getByProject(id);
    if (state == null || state.status == TimerStatus.stopped) return;
    if (state.status == TimerStatus.running &&
        state.runningStartedAtUtc != null) {
      final seconds = now.difference(state.runningStartedAtUtc!).inSeconds;
      if (seconds > 0) {
        await _db.timeEntriesDao.insertEntry(TimeEntriesCompanion(
          id: Value(_ids.newId()),
          projectId: Value(id),
          entryType: const Value(EntryType.timerSegment),
          signedDurationSeconds: Value(seconds),
          startedAtUtc: Value(state.runningStartedAtUtc),
          endedAtUtc: Value(now),
          effectiveAtUtc: Value(state.runningStartedAtUtc),
          createdAtUtc: Value(now),
        ));
      }
    }
    await _db.timerDao.upsert(TimerStatesCompanion(
      projectId: Value(id),
      status: const Value(TimerStatus.stopped),
      runningStartedAtUtc: const Value(null),
      updatedAtUtc: Value(now),
    ));
    await _logEvent(id, EventType.timerStopped, now);
  }

  Future<void> _logEvent(String projectId, EventType type, DateTime now) async {
    await _db.eventsDao.insertEvent(ActivityEventsCompanion(
      id: Value(_ids.newId()),
      projectId: Value(projectId),
      eventType: Value(type),
      occurredAtUtc: Value(now),
    ));
  }

  static String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
