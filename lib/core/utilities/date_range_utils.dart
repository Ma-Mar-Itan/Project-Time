/// The selectable statistics/history time ranges.
enum StatRangeType { today, week, month, year, all, custom }

extension StatRangeTypeLabel on StatRangeType {
  String get label => switch (this) {
        StatRangeType.today => 'Today',
        StatRangeType.week => 'This week',
        StatRangeType.month => 'This month',
        StatRangeType.year => 'This year',
        StatRangeType.all => 'All time',
        StatRangeType.custom => 'Custom',
      };
}

/// How daily/period chart buckets should be grouped for a given range.
enum BucketUnit { hour, day, week, month }

/// A half-open local date range: [start, end). Boundaries are local wall-clock
/// times even though the underlying data is stored in UTC.
class LocalDateRange {
  const LocalDateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime localInstant) =>
      !localInstant.isBefore(start) && localInstant.isBefore(end);

  Duration get span => end.difference(start);
}

/// Utilities for computing local calendar boundaries. "Today", "this week" and
/// "this month" are always resolved using the device's local timezone, while
/// storage remains in UTC.
class DateRangeUtils {
  const DateRangeUtils._();

  static DateTime startOfDay(DateTime local) =>
      DateTime(local.year, local.month, local.day);

  static DateTime startOfNextDay(DateTime local) =>
      startOfDay(local).add(const Duration(days: 1));

  /// Start of the week containing [local]. [firstDayOfWeek] uses
  /// `DateTime.monday`..`DateTime.sunday` (1..7).
  static DateTime startOfWeek(DateTime local, int firstDayOfWeek) {
    final day = startOfDay(local);
    final diff = (day.weekday - firstDayOfWeek + 7) % 7;
    return day.subtract(Duration(days: diff));
  }

  static DateTime startOfMonth(DateTime local) =>
      DateTime(local.year, local.month);

  static DateTime startOfYear(DateTime local) => DateTime(local.year);

  /// Resolves a [StatRangeType] to a concrete [LocalDateRange] given the
  /// current local time. For [StatRangeType.all] the start is the Unix epoch
  /// and the end is the start of tomorrow.
  static LocalDateRange resolve(
    StatRangeType type, {
    required DateTime nowLocal,
    int firstDayOfWeek = DateTime.monday,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final tomorrow = startOfNextDay(nowLocal);
    switch (type) {
      case StatRangeType.today:
        return LocalDateRange(startOfDay(nowLocal), tomorrow);
      case StatRangeType.week:
        return LocalDateRange(startOfWeek(nowLocal, firstDayOfWeek), tomorrow);
      case StatRangeType.month:
        return LocalDateRange(startOfMonth(nowLocal), tomorrow);
      case StatRangeType.year:
        return LocalDateRange(startOfYear(nowLocal), tomorrow);
      case StatRangeType.all:
        return LocalDateRange(DateTime(1970), tomorrow);
      case StatRangeType.custom:
        final start = startOfDay(customStart ?? startOfDay(nowLocal));
        final end = customEnd == null
            ? tomorrow
            : startOfNextDay(customEnd);
        return LocalDateRange(start, end);
    }
  }

  /// Picks a sensible chart bucket unit for a range type.
  static BucketUnit bucketUnitFor(StatRangeType type) => switch (type) {
        StatRangeType.today => BucketUnit.hour,
        StatRangeType.week => BucketUnit.day,
        StatRangeType.month => BucketUnit.day,
        StatRangeType.year => BucketUnit.week,
        StatRangeType.all => BucketUnit.month,
        StatRangeType.custom => BucketUnit.day,
      };

  /// Generates the ordered bucket start instants covering [range]. Buckets are
  /// local-time aligned. Used so charts never connect across missing data —
  /// every bucket in the range is present (possibly with a zero value).
  static List<DateTime> buckets(LocalDateRange range, BucketUnit unit) {
    final result = <DateTime>[];
    var cursor = switch (unit) {
      BucketUnit.hour =>
        DateTime(range.start.year, range.start.month, range.start.day,
            range.start.hour),
      BucketUnit.day => startOfDay(range.start),
      BucketUnit.week => startOfWeek(range.start, DateTime.monday),
      BucketUnit.month => startOfMonth(range.start),
    };
    while (cursor.isBefore(range.end)) {
      result.add(cursor);
      cursor = switch (unit) {
        BucketUnit.hour => cursor.add(const Duration(hours: 1)),
        BucketUnit.day => DateTime(cursor.year, cursor.month, cursor.day + 1),
        BucketUnit.week => cursor.add(const Duration(days: 7)),
        BucketUnit.month => DateTime(cursor.year, cursor.month + 1),
      };
    }
    return result;
  }

  /// Maps a local instant to the start of its bucket for the given unit.
  static DateTime bucketKey(DateTime local, BucketUnit unit) => switch (unit) {
        BucketUnit.hour =>
          DateTime(local.year, local.month, local.day, local.hour),
        BucketUnit.day => startOfDay(local),
        BucketUnit.week => startOfWeek(local, DateTime.monday),
        BucketUnit.month => startOfMonth(local),
      };
}
