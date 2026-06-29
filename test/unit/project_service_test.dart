import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/domain/models/enums.dart';
import 'package:project_time/domain/services/project_service.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  test('create makes a project, a stopped timer row and optional initial time',
      () async {
    final id = await s.projects.create(ProjectInput(
      name: '  Research  ',
      colorValue: 0xFF188038,
      initialTime: const Duration(hours: 1),
    ));

    final project = await s.db.projectsDao.getById(id);
    expect(project!.name, 'Research'); // trimmed
    final state = await s.db.timerDao.getByProject(id);
    expect(state!.status, TimerStatus.stopped);
    expect(await s.total(id), 3600); // initial time entry
  });

  test('archive hides the project and stops a running timer', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(minutes: 20));
    await s.projects.archive(id);

    final project = await s.db.projectsDao.getById(id);
    expect(project!.isArchived, isTrue);
    expect((await s.db.timerDao.getByProject(id))!.status, TimerStatus.stopped);
    expect(await s.total(id), 20 * 60); // segment finalized before archiving

    final active = await s.db.projectsDao.watchActive().first;
    expect(active.any((p) => p.id == id), isFalse);
  });

  test('restore brings the project back to the active list', () async {
    final id = await s.newProject();
    await s.projects.archive(id);
    await s.projects.restore(id);
    final active = await s.db.projectsDao.watchActive().first;
    expect(active.any((p) => p.id == id), isTrue);
  });

  test('delete removes records but keeps a global audit event', () async {
    final id = await s.newProject(name: 'Doomed');
    await s.adjustments.addManualTime(id, amount: const Duration(hours: 1));
    await s.projects.delete(id);

    expect(await s.db.projectsDao.getById(id), isNull);
    expect(await s.db.timeEntriesDao.getByProject(id), isEmpty);
    expect(await s.db.timerDao.getByProject(id), isNull);

    final events = await s.db.eventsDao.watchPaged(limit: 100).first;
    expect(
      events.any((e) =>
          e.eventType == EventType.projectDeleted && e.projectId == null),
      isTrue,
    );
  });
}
