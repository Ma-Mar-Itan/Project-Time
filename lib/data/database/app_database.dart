import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';
part 'daos/projects_dao.dart';
part 'daos/timer_dao.dart';
part 'daos/time_entries_dao.dart';
part 'daos/events_dao.dart';
part 'daos/settings_dao.dart';

@DriftDatabase(
  tables: [
    Projects,
    TimerStates,
    TimeEntries,
    ActivityEvents,
    SettingsEntries,
  ],
  daos: [
    ProjectsDao,
    TimerDao,
    TimeEntriesDao,
    EventsDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the on-device database (used by the app).
  factory AppDatabase.open() => AppDatabase(_openConnection());

  /// In-memory database for tests.
  factory AppDatabase.forTesting() =>
      AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  /// Wipes all user data (projects, timers, entries, events, settings) in a
  /// single transaction. Used by Settings → "Clear all application data".
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(activityEvents).go();
      await delete(timeEntries).go();
      await delete(timerStates).go();
      await delete(projects).go();
      await delete(settingsEntries).go();
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // No migrations yet (schema v1). Future schema changes are handled
          // here, step by step, e.g.:
          // if (from < 2) { await m.addColumn(...); }
        },
        beforeOpen: (details) async {
          // Enforce foreign-key constraints (off by default in SQLite).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, AppConstants.databaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
