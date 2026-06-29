import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/date_range_utils.dart';
import 'package:project_time/core/utilities/time_entry_splitter.dart';

void main() {
  // Note: inputs are passed as local wall-clock DateTimes; toLocal() is a
  // no-op on them, making these assertions timezone-independent.

  group('splitByLocalDay', () {
    test('splits a session that crosses midnight', () {
      final start = DateTime(2026, 1, 1, 23, 30);
      final end = DateTime(2026, 1, 2, 1, 30);
      final result =
          TimeEntrySplitter.splitByLocalDay(startUtc: start, endUtc: end);

      expect(result[DateTime(2026, 1, 1)], 30 * 60);
      expect(result[DateTime(2026, 1, 2)], 90 * 60);
    });

    test('keeps a same-day session in one bucket', () {
      final start = DateTime(2026, 1, 1, 9);
      final end = DateTime(2026, 1, 1, 11);
      final result =
          TimeEntrySplitter.splitByLocalDay(startUtc: start, endUtc: end);

      expect(result.length, 1);
      expect(result[DateTime(2026, 1, 1)], 2 * 3600);
    });

    test('spans multiple days', () {
      final start = DateTime(2026, 1, 1, 12);
      final end = DateTime(2026, 1, 3, 12);
      final result =
          TimeEntrySplitter.splitByLocalDay(startUtc: start, endUtc: end);

      expect(result[DateTime(2026, 1, 1)], 12 * 3600);
      expect(result[DateTime(2026, 1, 2)], 24 * 3600);
      expect(result[DateTime(2026, 1, 3)], 12 * 3600);
    });

    test('empty or inverted ranges yield nothing', () {
      final start = DateTime(2026, 1, 1, 12);
      expect(
        TimeEntrySplitter.splitByLocalDay(startUtc: start, endUtc: start),
        isEmpty,
      );
      expect(
        TimeEntrySplitter.splitByLocalDay(
            startUtc: start, endUtc: start.subtract(const Duration(hours: 1))),
        isEmpty,
      );
    });

    test('crosses a year boundary', () {
      final start = DateTime(2025, 12, 31, 23);
      final end = DateTime(2026, 1, 1, 1);
      final result =
          TimeEntrySplitter.splitByLocalDay(startUtc: start, endUtc: end);
      expect(result[DateTime(2025, 12, 31)], 3600);
      expect(result[DateTime(2026, 1, 1)], 3600);
    });
  });

  group('splitByBucket (hourly)', () {
    test('splits across hour buckets', () {
      final start = DateTime(2026, 1, 1, 10, 30);
      final end = DateTime(2026, 1, 1, 12, 15);
      final result = TimeEntrySplitter.splitByBucket(
          startUtc: start, endUtc: end, unit: BucketUnit.hour);

      expect(result[DateTime(2026, 1, 1, 10)], 30 * 60);
      expect(result[DateTime(2026, 1, 1, 11)], 60 * 60);
      expect(result[DateTime(2026, 1, 1, 12)], 15 * 60);
    });
  });
}
