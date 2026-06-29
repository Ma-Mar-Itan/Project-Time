import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/domain/services/export_service.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  test('CSV export includes a header and neutralizes formula injection',
      () async {
    final id = await s.newProject(name: 'Reporting');
    await s.adjustments.addManualTime(
      id,
      amount: const Duration(minutes: 15),
      note: '=DANGER()',
    );

    final csv = await s.export.buildCsv();
    expect(csv.startsWith('Project name,Entry type,'), isTrue);
    expect(csv.contains('Reporting'), isTrue);
    // The dangerous note must be escaped with a leading apostrophe.
    expect(csv.contains("'=DANGER()"), isTrue);
  });

  test('JSON backup validates and previews counts', () async {
    final id = await s.newProject(name: 'Backup me');
    await s.adjustments.addManualTime(id, amount: const Duration(hours: 1));

    final json = await s.export.buildBackupJson();
    final preview = s.export.validate(json);
    expect(preview.schemaVersion, 1);
    expect(preview.projects, 1);
    expect(preview.timeEntries, greaterThanOrEqualTo(1));
  });

  test('restore reproduces the data in a fresh database', () async {
    final id = await s.newProject(name: 'Original');
    await s.adjustments.addManualTime(id, amount: const Duration(hours: 2));
    final json = await s.export.buildBackupJson();

    final other = TestStack();
    addTearDown(other.dispose);
    await other.export.restore(json, replaceAll: true);

    final restored = await other.db.projectsDao.getById(id);
    expect(restored!.name, 'Original');
    expect(await other.total(id), 2 * 3600);
  });

  test('malformed backups are rejected and roll back', () async {
    final id = await s.newProject(name: 'Safe');
    expect(
      () => s.export.restore('this is not json', replaceAll: true),
      throwsA(isA<BackupException>()),
    );
    // Existing data untouched because validation failed before the transaction.
    expect(await s.db.projectsDao.getById(id), isNotNull);
  });

  test('duplicate IDs merge via upsert without duplicating rows', () async {
    final id = await s.newProject(name: 'Dup');
    final json = await s.export.buildBackupJson();
    // Restore into the SAME database with merge — IDs already exist.
    await s.export.restore(json, replaceAll: false);

    final all = await s.db.projectsDao.getAllIncludingArchived();
    expect(all.where((p) => p.id == id).length, 1);
  });
}
