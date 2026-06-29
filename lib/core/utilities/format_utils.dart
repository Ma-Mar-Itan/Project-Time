import 'package:intl/intl.dart';

import '../../domain/models/app_settings.dart';

/// Date/time and currency formatting helpers (display only — never used for
/// storage). Inputs are UTC and converted to local for display.
class FormatUtils {
  const FormatUtils._();

  static String timeOfDay(DateTime utc, ClockFormat format) {
    final local = utc.toLocal();
    final pattern = switch (format) {
      ClockFormat.h24 => 'HH:mm',
      ClockFormat.h12 => 'h:mm a',
      ClockFormat.system => 'jm',
    };
    return DateFormat(pattern).format(local);
  }

  static String dayMonthYear(DateTime utc) =>
      DateFormat('d MMMM yyyy').format(utc.toLocal());

  static String shortDate(DateTime utc) =>
      DateFormat('d MMM yyyy').format(utc.toLocal());

  static String dateTime(DateTime utc, ClockFormat format) =>
      '${dayMonthYear(utc)} · ${timeOfDay(utc, format)}';

  /// Human "time ago" for last-activity labels.
  static String relativeFromNow(DateTime utc, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toUtc();
    final diff = reference.difference(utc);
    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(utc);
  }

  /// Formats minor currency units (e.g. cents) to a currency string.
  static String currency(int minorUnits, String currencyCode) {
    final format = NumberFormat.simpleCurrency(name: currencyCode);
    final decimals = format.decimalDigits ?? 2;
    final value = minorUnits / _pow10(decimals);
    return format.format(value);
  }

  static num _pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}
