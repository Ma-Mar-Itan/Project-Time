import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/date_range_utils.dart';

import '../helpers/test_stack.dart';

void main() {
  late TestStack s;

  setUp(() => s = TestStack());
  tearDown(() => s.dispose());

  Future<dynamic> computeAll() {
    final range = DateRangeUtils.resolve(
      StatRangeType.all,
      nowLocal: s.clock.nowLocal(),
    );
    return s.statistics.computeFromDatabase(
      db: s.db,
      clock: s.clock,
      range: range,
      bucketUnit: BucketUnit.month,
    );
  }

  test('aggregates timer + manual time across the all-time range', () async {
    final id = await s.newProject(name: 'Alpha');
    await s.timer.start(id);
    s.clock.advance(const Duration(hours: 1));
    await s.timer.pause(id);
    await s.adjustments.addManualTime(id, amount: const Duration(minutes: 30));

    final result = await computeAll();

    expect(result.summary.totalSeconds, 3600 + 1800);
    expect(result.summary.sessionCount, 1);
    expect(result.summary.longestSessionSeconds, 3600);
    expect(result.sources.timerSeconds, 3600);
    expect(result.sources.additionSeconds, 1800);
    expect(result.sources.removalSeconds, 0);
    expect(result.summary.netManualSeconds, 1800);

    final alpha =
        result.byProject.firstWhere((p) => p.projectId == id);
    expect(alpha.seconds, 5400);
  });

  test('reset adjustments are excluded from tracked-time totals', () async {
    final id = await s.newProject();
    await s.adjustments.addManualTime(id, amount: const Duration(hours: 2));
    await s.adjustments.resetTotal(id);

    final result = await computeAll();
    // Stored total is 0, and tracked charts ignore reset, so the addition is
    // still counted but the reset is not subtracted in tracked charts.
    expect(result.sources.timerSeconds, 0);
    expect(result.sources.additionSeconds, 2 * 3600);
  });

  test('empty database yields an empty result', () async {
    final result = await computeAll();
    expect(result.isEmpty, isTrue);
  });
}
