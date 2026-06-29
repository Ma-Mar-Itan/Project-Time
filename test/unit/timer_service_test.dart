import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/domain/models/enums.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  test('start sets running state without creating completed time', () async {
    final id = await s.newProject();
    await s.timer.start(id);

    final state = await s.db.timerDao.getByProject(id);
    expect(state!.status, TimerStatus.running);
    expect(state.runningStartedAtUtc, isNotNull);
    expect(await s.total(id), 0);
  });

  test('double start is a no-op', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    final firstStart =
        (await s.db.timerDao.getByProject(id))!.runningStartedAtUtc;
    s.clock.advance(const Duration(minutes: 5));
    await s.timer.start(id); // should not reset the start time
    final secondStart =
        (await s.db.timerDao.getByProject(id))!.runningStartedAtUtc;
    expect(secondStart, firstStart);
  });

  test('pause finalizes a segment with the elapsed seconds', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 1));
    await s.timer.pause(id);

    expect(await s.total(id), 3600);
    final state = await s.db.timerDao.getByProject(id);
    expect(state!.status, TimerStatus.paused);
    expect(state.runningStartedAtUtc, isNull);
  });

  test('resume then stop accumulates across segments', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 1));
    await s.timer.pause(id);
    await s.timer.resume(id);
    s.clock.advance(const Duration(minutes: 30));
    await s.timer.stop(id);

    expect(await s.total(id), 3600 + 1800);
    expect((await s.db.timerDao.getByProject(id))!.status, TimerStatus.stopped);
  });

  test('stop while paused adds no extra time', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(minutes: 10));
    await s.timer.pause(id);
    final before = await s.total(id);
    await s.timer.stop(id);
    expect(await s.total(id), before);
  });

  test('running total includes the live segment (reopen scenario)', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 2));
    // No pause — simulates the app being reopened while running.
    expect(await s.adjustments.currentTotalSeconds(id), 2 * 3600);
  });

  test('multiple concurrent timers are independent', () async {
    final a = await s.newProject(name: 'A');
    final b = await s.newProject(name: 'B');
    await s.timer.start(a);
    await s.timer.start(b);
    s.clock.advance(const Duration(hours: 1));
    await s.timer.pause(a);

    expect(await s.total(a), 3600);
    final bState = await s.db.timerDao.getByProject(b);
    expect(bState!.status, TimerStatus.running);
    expect(await s.adjustments.currentTotalSeconds(b), 3600);
  });

  test('ten concurrent timers, pauseAll pauses all of them', () async {
    final ids = <String>[];
    for (var i = 0; i < 10; i++) {
      final id = await s.newProject(name: 'P$i');
      ids.add(id);
      await s.timer.start(id);
    }
    s.clock.advance(const Duration(minutes: 15));
    final paused = await s.timer.pauseAll();

    expect(paused, 10);
    for (final id in ids) {
      final state = await s.db.timerDao.getByProject(id);
      expect(state!.status, TimerStatus.paused);
      expect(await s.total(id), 15 * 60);
    }
  });

  test('timer running across a month boundary records full duration', () async {
    s.clock.setUtc(DateTime.utc(2026, 1, 31, 23, 0));
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 2)); // into Feb 1
    await s.timer.stop(id);
    expect(await s.total(id), 2 * 3600);
  });
}
