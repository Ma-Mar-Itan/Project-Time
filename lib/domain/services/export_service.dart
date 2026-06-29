import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utilities/clock.dart';
import '../../core/utilities/csv_utils.dart';
import '../../core/utilities/duration_formatter.dart';
import '../../data/database/app_database.dart';
import '../models/enums.dart';

/// Raised when a backup file is malformed or unsupported.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => 'BackupException: $message';
}

/// Counts previewed to the user before importing a backup.
class BackupPreview {
  const BackupPreview({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.projects,
    required this.timeEntries,
    required this.activityEvents,
  });

  final int schemaVersion;
  final DateTime? exportedAtUtc;
  final int projects;
  final int timeEntries;
  final int activityEvents;
}

/// CSV export and JSON backup/restore. Pure string in/out so it is fully
/// testable; file IO and sharing live in the presentation layer.
class ExportService {
  ExportService({required AppDatabase db, required Clock clock})
      : _db = db,
        _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  static const _csvHeader = [
    'Project name',
    'Entry type',
    'Start date',
    'End date',
    'Signed duration seconds',
    'Human-readable duration',
    'Effective date',
    'Note',
    'Created date',
  ];

  /// Builds a CSV document. Optionally scoped to one [projectId] and/or a
  /// local effective date range.
  Future<String> buildCsv({
    String? projectId,
    DateTime? startUtc,
    DateTime? endUtc,
  }) async {
    final projects = await _db.projectsDao.getAllIncludingArchived();
    final namesById = {for (final p in projects) p.id: p.name};

    var entries = await _db.timeEntriesDao.getAll();
    entries = entries.where((e) {
      if (projectId != null && e.projectId != projectId) return false;
      if (startUtc != null && e.effectiveAtUtc.isBefore(startUtc)) return false;
      if (endUtc != null && !e.effectiveAtUtc.isBefore(endUtc)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.effectiveAtUtc.compareTo(b.effectiveAtUtc));

    final rows = entries.map((e) {
      final duration = Duration(seconds: e.signedDurationSeconds);
      return <Object?>[
        namesById[e.projectId] ?? 'Unknown project',
        e.entryType.label,
        e.startedAtUtc?.toIso8601String() ?? '',
        e.endedAtUtc?.toIso8601String() ?? '',
        e.signedDurationSeconds,
        DurationFormatter.signed(duration),
        e.effectiveAtUtc.toIso8601String(),
        e.note ?? '',
        e.createdAtUtc.toIso8601String(),
      ];
    }).toList();

    return CsvUtils.build(_csvHeader, rows);
  }

  /// Serializes the entire database to a JSON backup string.
  Future<String> buildBackupJson() async {
    final projects = await _db.select(_db.projects).get();
    final timerStates = await _db.select(_db.timerStates).get();
    final timeEntries = await _db.select(_db.timeEntries).get();
    final events = await _db.select(_db.activityEvents).get();
    final settings = await _db.settingsDao.getAll();

    final payload = <String, dynamic>{
      'schemaVersion': AppConstants.backupSchemaVersion,
      'exportedAtUtc': _clock.nowUtc().toIso8601String(),
      'projects': projects.map(_projectToJson).toList(),
      'timerStates': timerStates.map(_timerToJson).toList(),
      'timeEntries': timeEntries.map(_entryToJson).toList(),
      'activityEvents': events.map(_eventToJson).toList(),
      'settings': settings,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Validates a backup string and returns a preview of its contents.
  BackupPreview validate(String json) {
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw BackupException('Backup root must be a JSON object.');
      }
      data = decoded;
    } on FormatException catch (e) {
      throw BackupException('Invalid JSON: ${e.message}');
    }

    final version = data['schemaVersion'];
    if (version is! int) {
      throw BackupException('Missing or invalid schemaVersion.');
    }
    if (version > AppConstants.backupSchemaVersion) {
      throw BackupException(
          'Backup schema v$version is newer than this app supports.');
    }
    for (final key in ['projects', 'timeEntries', 'activityEvents']) {
      if (data[key] is! List) {
        throw BackupException('Missing "$key" array.');
      }
    }

    return BackupPreview(
      schemaVersion: version,
      exportedAtUtc: DateTime.tryParse(data['exportedAtUtc']?.toString() ?? ''),
      projects: (data['projects'] as List).length,
      timeEntries: (data['timeEntries'] as List).length,
      activityEvents: (data['activityEvents'] as List).length,
    );
  }

  /// Restores a backup inside a single transaction. When [replaceAll] is true
  /// all existing data is wiped first; otherwise records are merged by primary
  /// key (existing IDs are upserted/skipped). Rolls back entirely on failure.
  Future<void> restore(String json, {required bool replaceAll}) async {
    validate(json); // throws on malformed input
    final data = jsonDecode(json) as Map<String, dynamic>;

    await _db.transaction(() async {
      if (replaceAll) {
        await _db.delete(_db.activityEvents).go();
        await _db.delete(_db.timeEntries).go();
        await _db.delete(_db.timerStates).go();
        await _db.delete(_db.projects).go();
      }

      for (final raw in (data['projects'] as List)) {
        await _db.into(_db.projects).insertOnConflictUpdate(
            _projectFromJson(raw as Map<String, dynamic>));
      }
      for (final raw in (data['timerStates'] as List? ?? const [])) {
        await _db.into(_db.timerStates).insertOnConflictUpdate(
            _timerFromJson(raw as Map<String, dynamic>));
      }
      for (final raw in (data['timeEntries'] as List)) {
        await _db.into(_db.timeEntries).insertOnConflictUpdate(
            _entryFromJson(raw as Map<String, dynamic>));
      }
      for (final raw in (data['activityEvents'] as List)) {
        await _db.into(_db.activityEvents).insertOnConflictUpdate(
            _eventFromJson(raw as Map<String, dynamic>));
      }
      final settings = data['settings'];
      if (settings is Map) {
        await _db.settingsDao.putAll(
            settings.map((k, v) => MapEntry(k.toString(), v.toString())));
      }

      // Audit the import.
      await _db.eventsDao.insertEvent(ActivityEventsCompanion(
        id: Value(const Uuid().v4()),
        projectId: const Value(null),
        eventType: const Value(EventType.dataImported),
        occurredAtUtc: Value(_clock.nowUtc()),
        note: Value(replaceAll ? 'Replaced all data' : 'Merged data'),
      ));
    });
  }

  // --- row <-> json ---

  static String? _iso(DateTime? d) => d?.toIso8601String();
  static DateTime _date(Object? v) =>
      DateTime.parse(v.toString()).toUtc();
  static DateTime? _dateN(Object? v) =>
      v == null ? null : DateTime.parse(v.toString()).toUtc();

  Map<String, dynamic> _projectToJson(Project p) => {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'clientOrCategory': p.clientOrCategory,
        'notes': p.notes,
        'colorValue': p.colorValue,
        'hourlyRateMinorUnits': p.hourlyRateMinorUnits,
        'currencyCode': p.currencyCode,
        'deadlineUtc': _iso(p.deadlineUtc),
        'createdAtUtc': _iso(p.createdAtUtc),
        'updatedAtUtc': _iso(p.updatedAtUtc),
        'lastActivityAtUtc': _iso(p.lastActivityAtUtc),
        'archivedAtUtc': _iso(p.archivedAtUtc),
        'isArchived': p.isArchived,
        'deletedAtUtc': _iso(p.deletedAtUtc),
      };

  ProjectsCompanion _projectFromJson(Map<String, dynamic> j) =>
      ProjectsCompanion.insert(
        id: j['id'] as String,
        name: j['name'] as String,
        description: Value(j['description'] as String?),
        clientOrCategory: Value(j['clientOrCategory'] as String?),
        notes: Value(j['notes'] as String?),
        colorValue: j['colorValue'] as int,
        hourlyRateMinorUnits: Value(j['hourlyRateMinorUnits'] as int?),
        currencyCode: Value(j['currencyCode'] as String?),
        deadlineUtc: Value(_dateN(j['deadlineUtc'])),
        createdAtUtc: _date(j['createdAtUtc']),
        updatedAtUtc: _date(j['updatedAtUtc']),
        lastActivityAtUtc: Value(_dateN(j['lastActivityAtUtc'])),
        archivedAtUtc: Value(_dateN(j['archivedAtUtc'])),
        isArchived: Value(j['isArchived'] as bool? ?? false),
        deletedAtUtc: Value(_dateN(j['deletedAtUtc'])),
      );

  Map<String, dynamic> _timerToJson(TimerState t) => {
        'projectId': t.projectId,
        'status': t.status.name,
        'runningStartedAtUtc': _iso(t.runningStartedAtUtc),
        'updatedAtUtc': _iso(t.updatedAtUtc),
      };

  TimerStatesCompanion _timerFromJson(Map<String, dynamic> j) =>
      TimerStatesCompanion.insert(
        projectId: j['projectId'] as String,
        status: TimerStatus.values.byName(j['status'] as String),
        runningStartedAtUtc: Value(_dateN(j['runningStartedAtUtc'])),
        updatedAtUtc: _date(j['updatedAtUtc']),
      );

  Map<String, dynamic> _entryToJson(TimeEntry e) => {
        'id': e.id,
        'projectId': e.projectId,
        'entryType': e.entryType.name,
        'signedDurationSeconds': e.signedDurationSeconds,
        'startedAtUtc': _iso(e.startedAtUtc),
        'endedAtUtc': _iso(e.endedAtUtc),
        'effectiveAtUtc': _iso(e.effectiveAtUtc),
        'note': e.note,
        'createdAtUtc': _iso(e.createdAtUtc),
        'updatedAtUtc': _iso(e.updatedAtUtc),
        'metadataJson': e.metadataJson,
      };

  TimeEntriesCompanion _entryFromJson(Map<String, dynamic> j) =>
      TimeEntriesCompanion.insert(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        entryType: EntryType.values.byName(j['entryType'] as String),
        signedDurationSeconds: j['signedDurationSeconds'] as int,
        startedAtUtc: Value(_dateN(j['startedAtUtc'])),
        endedAtUtc: Value(_dateN(j['endedAtUtc'])),
        effectiveAtUtc: _date(j['effectiveAtUtc']),
        note: Value(j['note'] as String?),
        createdAtUtc: _date(j['createdAtUtc']),
        updatedAtUtc: Value(_dateN(j['updatedAtUtc'])),
        metadataJson: Value(j['metadataJson'] as String?),
      );

  Map<String, dynamic> _eventToJson(ActivityEvent e) => {
        'id': e.id,
        'projectId': e.projectId,
        'eventType': e.eventType.name,
        'occurredAtUtc': _iso(e.occurredAtUtc),
        'durationSeconds': e.durationSeconds,
        'note': e.note,
        'metadataJson': e.metadataJson,
      };

  ActivityEventsCompanion _eventFromJson(Map<String, dynamic> j) =>
      ActivityEventsCompanion.insert(
        id: j['id'] as String,
        projectId: Value(j['projectId'] as String?),
        eventType: EventType.values.byName(j['eventType'] as String),
        occurredAtUtc: _date(j['occurredAtUtc']),
        durationSeconds: Value(j['durationSeconds'] as int?),
        note: Value(j['note'] as String?),
        metadataJson: Value(j['metadataJson'] as String?),
      );
}
