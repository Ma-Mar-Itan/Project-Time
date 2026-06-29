import 'package:flutter_test/flutter_test.dart';
import 'package:project_time/core/utilities/duration_formatter.dart';

void main() {
  group('DurationFormatter.full', () {
    test('formats the documented example 02:14:07:32:10', () {
      final d = const Duration(days: 74, hours: 7, minutes: 32, seconds: 10);
      // 74 days = 2 thirty-day months + 14 days.
      expect(DurationFormatter.full(d), '02:14:07:32:10');
    });

    test('zero duration', () {
      expect(DurationFormatter.full(Duration.zero), '00:00:00:00:00');
    });

    test('months exceed two digits and are not truncated', () {
      final d = Duration(days: 30 * 100); // 100 months
      expect(DurationFormatter.full(d), '100:00:00:00:00');
    });

    test('negative durations are prefixed', () {
      expect(DurationFormatter.full(const Duration(hours: -1)),
          '-00:00:01:00:00');
    });
  });

  group('DurationFormatter.compact', () {
    test('shows two most significant units', () {
      expect(DurationFormatter.compact(const Duration(hours: 4, minutes: 32)),
          '4h 32m');
      expect(DurationFormatter.compact(const Duration(days: 12, hours: 4)),
          '12d 4h');
      expect(DurationFormatter.compact(Duration(days: 74)), '2mo 14d');
    });

    test('single unit and zero', () {
      expect(DurationFormatter.compact(const Duration(minutes: 45)), '45m');
      expect(DurationFormatter.compact(Duration.zero), '0s');
    });
  });

  group('DurationFormatter.spoken', () {
    test('reads up to three units naturally', () {
      final d = const Duration(days: 2, hours: 4, minutes: 17);
      expect(DurationFormatter.spoken(d), '2 days 4 hours 17 minutes');
    });

    test('singular vs plural', () {
      expect(DurationFormatter.spoken(const Duration(hours: 1)), '1 hour');
    });

    test('zero', () {
      expect(DurationFormatter.spoken(Duration.zero), '0 seconds');
    });
  });

  group('DurationFormatter.fromUnits', () {
    test('one month equals 30 days', () {
      expect(DurationFormatter.fromUnits(months: 1), Duration(days: 30));
    });

    test('combined units', () {
      final d = DurationFormatter.fromUnits(
          days: 1, hours: 2, minutes: 3, seconds: 4);
      expect(d.inSeconds, 86400 + 7200 + 180 + 4);
    });
  });

  group('DurationFormatter.signed', () {
    test('positive, negative and zero', () {
      expect(DurationFormatter.signed(const Duration(minutes: 45)), '+45m');
      expect(DurationFormatter.signed(const Duration(minutes: -45)), '-45m');
      expect(DurationFormatter.signed(Duration.zero), '0s');
    });
  });

  group('large durations', () {
    test('several years stay accurate as integer seconds', () {
      final d = Duration(days: 365 * 5); // ~5 years
      final components = DurationComponents.fromDuration(d);
      // 1825 days / 30 = 60 months remainder 25 days.
      expect(components.months, 60);
      expect(components.days, 25);
    });
  });
}
