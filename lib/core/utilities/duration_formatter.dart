import '../constants/app_constants.dart';

/// Decomposition of a duration into 30-day months, days, hours, minutes and
/// seconds. Used to render the boxed MO:DD:HH:MM:SS display.
class DurationComponents {
  const DurationComponents({
    required this.isNegative,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final bool isNegative;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  factory DurationComponents.fromDuration(Duration duration) {
    final isNegative = duration.isNegative;
    var total = duration.inSeconds.abs();
    final months = total ~/ AppConstants.secondsPerDisplayMonth;
    total %= AppConstants.secondsPerDisplayMonth;
    final days = total ~/ AppConstants.secondsPerDay;
    total %= AppConstants.secondsPerDay;
    final hours = total ~/ AppConstants.secondsPerHour;
    total %= AppConstants.secondsPerHour;
    final minutes = total ~/ AppConstants.secondsPerMinute;
    final seconds = total % AppConstants.secondsPerMinute;
    return DurationComponents(
      isNegative: isNegative,
      months: months,
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }
}

/// Formats and parses durations.
///
/// Durations are always stored as integer seconds. This utility never persists
/// formatted strings — it only renders them for display and parses user input.
class DurationFormatter {
  const DurationFormatter._();

  /// Builds a [Duration] from explicit unit inputs, where one month == 30 days.
  static Duration fromUnits({
    int months = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
  }) {
    final totalSeconds = months * AppConstants.secondsPerDisplayMonth +
        days * AppConstants.secondsPerDay +
        hours * AppConstants.secondsPerHour +
        minutes * AppConstants.secondsPerMinute +
        seconds;
    return Duration(seconds: totalSeconds);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Full MO:DD:HH:MM:SS format. Months use a minimum width of two digits but
  /// may grow beyond two for very long durations (never truncated).
  ///
  /// Example: `Duration(days: 74, hours: 7, minutes: 32, seconds: 10)`
  /// renders as `02:14:07:32:10`.
  static String full(Duration duration, {String separator = ':'}) {
    final c = DurationComponents.fromDuration(duration);
    final body = <String>[
      c.months.toString().padLeft(2, '0'),
      _two(c.days),
      _two(c.hours),
      _two(c.minutes),
      _two(c.seconds),
    ].join(separator);
    return c.isNegative ? '-$body' : body;
  }

  /// Compact, human-readable format showing the two most significant non-zero
  /// units. Examples: `4h 32m`, `12d 4h`, `2mo 14d`, `45m`, `0s`.
  static String compact(Duration duration) {
    final c = DurationComponents.fromDuration(duration);
    final units = <MapEntry<int, String>>[
      MapEntry(c.months, 'mo'),
      MapEntry(c.days, 'd'),
      MapEntry(c.hours, 'h'),
      MapEntry(c.minutes, 'm'),
      MapEntry(c.seconds, 's'),
    ];
    final firstIndex = units.indexWhere((e) => e.key != 0);
    if (firstIndex == -1) return '0s';

    final parts = <String>['${units[firstIndex].key}${units[firstIndex].value}'];
    if (firstIndex + 1 < units.length && units[firstIndex + 1].key != 0) {
      parts.add('${units[firstIndex + 1].key}${units[firstIndex + 1].value}');
    }
    final body = parts.join(' ');
    return c.isNegative ? '-$body' : body;
  }

  /// Screen-reader-friendly description, e.g. "2 days 4 hours 17 minutes".
  /// Shows up to three most significant non-zero units. Empty durations read
  /// as "0 seconds".
  static String spoken(Duration duration) {
    final c = DurationComponents.fromDuration(duration);
    final units = <MapEntry<int, String>>[
      MapEntry(c.months, 'month'),
      MapEntry(c.days, 'day'),
      MapEntry(c.hours, 'hour'),
      MapEntry(c.minutes, 'minute'),
      MapEntry(c.seconds, 'second'),
    ];
    final spokenParts = <String>[];
    for (final unit in units) {
      if (unit.key == 0) continue;
      final plural = unit.key == 1 ? unit.value : '${unit.value}s';
      spokenParts.add('${unit.key} $plural');
      if (spokenParts.length == 3) break;
    }
    if (spokenParts.isEmpty) return '0 seconds';
    final body = spokenParts.join(' ');
    return c.isNegative ? 'negative $body' : body;
  }

  /// Signed compact form that always shows an explicit + or - sign. Used for
  /// manual adjustments in history and lists.
  static String signed(Duration duration) {
    if (duration.inSeconds == 0) return '0s';
    final sign = duration.isNegative ? '-' : '+';
    return '$sign${compact(duration.abs())}';
  }
}
