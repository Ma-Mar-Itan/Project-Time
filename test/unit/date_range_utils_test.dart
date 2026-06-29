import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/date_range_utils.dart';

void main() {
  group('startOfDay / startOfWeek', () {
    test('startOfDay strips the time component', () {
      final d = DateTime(2026, 6, 29, 15, 42, 7);
      expect(DateRangeUtils.startOfDay(d), DateTime(2026, 6, 29));
    });

    test('startOfWeek with Monday lands on a Monday', () {
      final d = DateTime(2026, 6, 29, 15);
      final start = DateRangeUtils.startOfWeek(d, DateTime.monday);
      expect(start.weekday, DateTime.monday);
      expect(start.isAfter(d), isFalse);
      expect(d.difference(start).inDays, lessThan(7));
    });

    test('startOfWeek with Sunday lands on a Sunday', () {
      final d = DateTime(2026, 6, 29, 15);
      final start = DateRangeUtils.startOfWeek(d, DateTime.sunday);
      expect(start.weekday, DateTime.sunday);
    });
  });

  group('resolve', () {
    final now = DateTime(2026, 6, 29, 15, 30);

    test('today is [startOfDay, startOfTomorrow)', () {
      final range = DateRangeUtils.resolve(StatRangeType.today, nowLocal: now);
      expect(range.start, DateTime(2026, 6, 29));
      expect(range.end, DateTime(2026, 6, 30));
    });

    test('month starts on the 1st', () {
      final range = DateRangeUtils.resolve(StatRangeType.month, nowLocal: now);
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 6, 30));
    });

    test('year starts in January', () {
      final range = DateRangeUtils.resolve(StatRangeType.year, nowLocal: now);
      expect(range.start, DateTime(2026, 1, 1));
    });

    test('custom uses inclusive day boundaries', () {
      final range = DateRangeUtils.resolve(
        StatRangeType.custom,
        nowLocal: now,
        customStart: DateTime(2026, 6, 1, 9),
        customEnd: DateTime(2026, 6, 7, 18),
      );
      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 6, 8));
    });

    test('contains works on the half-open range', () {
      final range = DateRangeUtils.resolve(StatRangeType.today, nowLocal: now);
      expect(range.contains(DateTime(2026, 6, 29, 0)), isTrue);
      expect(range.contains(DateTime(2026, 6, 30, 0)), isFalse);
    });
  });

  group('bucketUnitFor', () {
    test('maps range to bucket unit', () {
      expect(DateRangeUtils.bucketUnitFor(StatRangeType.today), BucketUnit.hour);
      expect(DateRangeUtils.bucketUnitFor(StatRangeType.week), BucketUnit.day);
      expect(DateRangeUtils.bucketUnitFor(StatRangeType.year), BucketUnit.week);
      expect(DateRangeUtils.bucketUnitFor(StatRangeType.all), BucketUnit.month);
    });
  });

  group('buckets', () {
    test('generates one bucket per day across a week', () {
      final range = LocalDateRange(DateTime(2026, 6, 1), DateTime(2026, 6, 8));
      final buckets = DateRangeUtils.buckets(range, BucketUnit.day);
      expect(buckets.length, 7);
      expect(buckets.first, DateTime(2026, 6, 1));
      expect(buckets.last, DateTime(2026, 6, 7));
    });
  });
}
