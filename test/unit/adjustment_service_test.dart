import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/domain/models/enums.dart';
import 'package:project_time/domain/services/adjustment_service.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  test('addManualTime increases the total', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 45));
    expect(await s.total(id), 45 * 60);
  });

  test('removeManualTime decreases the total', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(hours: 2));
    await s.adjustments
        .removeManualTime(id, amount: const Duration(minutes: 30));
    expect(await s.total(id), 2 * 3600 - 30 * 60);
  });

  test('removal cannot exceed the current total', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 10));
    expect(
      () => s.adjustments.removeManualTime(id, amount: const Duration(hours: 1)),
      throwsA(isA<AdjustmentException>()),
    );
    expect(await s.total(id), 10 * 60); // unchanged
  });

  test('zero or negative durations are rejected', () async {
    final id = await s.newProject();
    expect(
      () => s.adjustments.addManualTime(id, amount: Duration.zero),
      throwsA(isA<AdjustmentException>()),
    );
  });

  test('removal accounts for the live running segment', () async {
    final id = await s.newProject();
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 1));
    // 1h is currently live (not yet persisted). Removing 30m is allowed.
    await s.adjustments
        .removeManualTime(id, amount: const Duration(minutes: 30));
    // currentTotal = 3600 live - 1800 removal = 1800.
    expect(await s.adjustments.currentTotalSeconds(id), 1800);
  });

  group('reset', () {
    test('reset writes a negative adjustment and zeroes the total', () async {
      final id = await s.newProject();
      await s.adjustments.addManualTime(id, amount: const Duration(hours: 3));
      await s.adjustments.resetTotal(id, reason: 'fresh start');

      expect(await s.total(id), 0);
      // History preserved: addition + reset entries both exist.
      final entries = await s.db.timeEntriesDao.getByProject(id);
      expect(entries.length, 2);
      expect(
        entries.any((e) => e.entryType == EntryType.resetAdjustment),
        isTrue,
      );
    });

    test('reset while running finalizes the segment then zeroes', () async {
      final id = await s.newProject();
      await s.timer.start(id);
      s.clock.advance(const Duration(hours: 1));
      await s.adjustments.resetTotal(id);

      expect(await s.total(id), 0);
      final state = await s.db.timerDao.getByProject(id);
      expect(state!.status, TimerStatus.stopped);
    });
  });
}
