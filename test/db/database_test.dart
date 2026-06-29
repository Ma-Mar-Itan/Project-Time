import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/data/database/app_database.dart';
import 'package:project_time/domain/models/enums.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  test('foreign keys are enforced', () async {
    expect(
      () => s.db.timeEntriesDao.insertEntry(TimeEntriesCompanion.insert(
        id: 'x',
        projectId: 'does-not-exist',
        entryType: EntryType.timerSegment,
        signedDurationSeconds: 60,
        effectiveAtUtc: DateTime.utc(2026, 1, 1),
        createdAtUtc: DateTime.utc(2026, 1, 1),
      )),
      throwsA(anything),
    );
  });

  test('deleting a project cascades to its time entries', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 5));
    expect(await s.db.timeEntriesDao.getByProject(id), isNotEmpty);

    await (s.db.delete(s.db.projects)..where((t) => t.id.equals(id))).go();
    expect(await s.db.timeEntriesDao.getByProject(id), isEmpty);
  });

  test('project totals query is reactive', () async {
    final id = await s.newProject();
    final stream = s.db.timeEntriesDao.watchProjectTotals();
    final first = await stream.first;
    expect(first[id] ?? 0, 0);

    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 10));
    final updated =
        await stream.firstWhere((m) => (m[id] ?? 0) == 600);
    expect(updated[id], 600);
  });

  test('clearAllData empties every table', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 5));
    await s.db.settingsDao.put('themeMode', 'dark');

    await s.db.clearAllData();

    expect(await s.db.projectsDao.getAllIncludingArchived(), isEmpty);
    expect(await s.db.timeEntriesDao.getAll(), isEmpty);
    expect(await s.db.settingsDao.getAll(), isEmpty);
  });
}
