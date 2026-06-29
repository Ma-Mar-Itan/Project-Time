import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/clock.dart';
import 'package:project_time/core/utilities/date_range_utils.dart';
import 'package:project_time/data/database/app_database.dart';
import 'package:project_time/domain/models/enums.dart';
import 'package:project_time/domain/services/adjustment_service.dart';
import 'package:project_time/domain/services/project_service.dart';
import 'package:project_time/domain/services/timer_service.dart';

import '../helpers/test_doubles.dart';
import '../helpers/test_stack.dart';

void main() {
  test('full flow: two projects, timers, manual time, stats', () async {
    final s = TestStack(initial: DateTime.utc(2026, 3, 10, 9));
    addTearDown(s.dispose);

    // 1-3. Create two projects and start both timers.
    final a = await s.newProject(name: 'Alpha');
    final b = await s.newProject(name: 'Beta');
    await s.timer.start(a);
    await s.timer.start(b);

    // 4. Simulate one hour of elapsed time via the injected clock.
    s.clock.advance(const Duration(hours: 1));

    // 5. Pause one.
    await s.timer.pause(a);

    // 6. Add manual time to the other.
    await s.adjustments.addManualTime(b, amount: const Duration(minutes: 30));

    // 7. Stop both.
    await s.timer.stop(a);
    await s.timer.stop(b);

    // 8. Verify totals: Alpha 1h; Beta 1h (timer) + 30m (manual).
    expect(await s.total(a), 3600);
    expect(await s.total(b), 3600 + 1800);

    // 9. Verify history contains the key events.
    final events = await s.db.eventsDao.watchPaged(limit: 200).first;
    expect(events.any((e) => e.eventType == EventType.timerStarted), isTrue);
    expect(events.any((e) => e.eventType == EventType.manualAdded), isTrue);
    expect(events.any((e) => e.eventType == EventType.timerStopped), isTrue);

    // 10. Verify statistics reflect both projects.
    final range = DateRangeUtils.resolve(
      StatRangeType.all,
      nowLocal: s.clock.nowLocal(),
    );
    final stats = await s.statistics.computeFromDatabase(
      db: s.db,
      clock: s.clock,
      range: range,
      bucketUnit: BucketUnit.month,
    );
    expect(stats.summary.totalSeconds, 3600 + 3600 + 1800);
    expect(stats.byProject.length, 2);
  });

  test('running timer persists across an app restart (file-backed db)',
      () async {
    final dir = await Directory.systemTemp.createTemp('project_time_test');
    final file = File('${dir.path}/db.sqlite');
    final clock = FakeClock(DateTime.utc(2026, 3, 10, 9));
    final ids = CounterIdGenerator();

    // First "session": create a project and start its timer, then close.
    var db = AppDatabase(NativeDatabase(file));
    var projects = ProjectService(db: db, clock: clock, ids: ids);
    var timer = TimerService(db: db, clock: clock, ids: ids);
    final id = await projects
        .create(ProjectInput(name: 'Persistent', colorValue: 0xFF1A73E8));
    await timer.start(id);
    await db.close();

    // Time passes while the app is closed.
    clock.advance(const Duration(hours: 3));

    // Second "session": reopen the same file. The timer is still running and
    // its elapsed time is computed from the persisted start timestamp.
    db = AppDatabase(NativeDatabase(file));
    final adjustments = AdjustmentService(db: db, clock: clock, ids: ids);
    final state = await db.timerDao.getByProject(id);
    expect(state!.status, TimerStatus.running);
    expect(await adjustments.currentTotalSeconds(id), 3 * 3600);

    await db.close();
    await dir.delete(recursive: true);
  });
}
