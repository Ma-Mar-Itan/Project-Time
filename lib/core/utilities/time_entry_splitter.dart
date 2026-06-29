import 'date_range_utils.dart';

/// Splits a timer segment's duration across local calendar-day boundaries.
///
/// A timer that runs from 11:30 PM to 1:30 AM local time should allocate 30
/// minutes to the first day and 90 minutes to the next day, rather than
/// assigning the whole session to its start date.
class TimeEntrySplitter {
  const TimeEntrySplitter._();

  /// Returns a map of local-day-start -> seconds for the segment defined by
  /// [startUtc] and [endUtc]. Inputs may be in any timezone; they are converted
  /// to local time for bucketing. Returns an empty map if the segment is empty
  /// or inverted.
  static Map<DateTime, int> splitByLocalDay({
    required DateTime startUtc,
    required DateTime endUtc,
  }) {
    final start = startUtc.toLocal();
    final end = endUtc.toLocal();
    if (!end.isAfter(start)) return const {};

    final result = <DateTime, int>{};
    var cursor = start;
    while (cursor.isBefore(end)) {
      final dayStart = DateRangeUtils.startOfDay(cursor);
      final nextDay = DateRangeUtils.startOfNextDay(cursor);
      final segmentEnd = end.isBefore(nextDay) ? end : nextDay;
      final seconds = segmentEnd.difference(cursor).inSeconds;
      if (seconds > 0) {
        result.update(dayStart, (v) => v + seconds, ifAbsent: () => seconds);
      }
      cursor = segmentEnd;
    }
    return result;
  }

  /// Distributes a segment's duration across the buckets of [unit], honoring
  /// local boundaries. Used by the "time over time" chart. Returns local
  /// bucket-start -> seconds.
  static Map<DateTime, int> splitByBucket({
    required DateTime startUtc,
    required DateTime endUtc,
    required BucketUnit unit,
  }) {
    final start = startUtc.toLocal();
    final end = endUtc.toLocal();
    if (!end.isAfter(start)) return const {};

    final result = <DateTime, int>{};
    var cursor = start;
    while (cursor.isBefore(end)) {
      final bucketStart = DateRangeUtils.bucketKey(cursor, unit);
      final nextBucket = _advance(bucketStart, unit);
      final segmentEnd = end.isBefore(nextBucket) ? end : nextBucket;
      final seconds = segmentEnd.difference(cursor).inSeconds;
      if (seconds > 0) {
        result.update(bucketStart, (v) => v + seconds, ifAbsent: () => seconds);
      }
      cursor = segmentEnd;
    }
    return result;
  }

  static DateTime _advance(DateTime bucketStart, BucketUnit unit) =>
      switch (unit) {
        BucketUnit.hour => bucketStart.add(const Duration(hours: 1)),
        BucketUnit.day =>
          DateTime(bucketStart.year, bucketStart.month, bucketStart.day + 1),
        BucketUnit.week => bucketStart.add(const Duration(days: 7)),
        BucketUnit.month => DateTime(bucketStart.year, bucketStart.month + 1),
      };
}
