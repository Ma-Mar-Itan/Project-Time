import 'package:flutter/material.dart';

import '../../core/utilities/date_range_utils.dart';

enum DurationDisplayMode { full, compact }

enum ClockFormat { system, h12, h24 }

/// Immutable application settings, (de)serialized to a key-value string map.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.firstDayOfWeek = DateTime.monday,
    this.defaultStatRange = StatRangeType.week,
    this.durationDisplay = DurationDisplayMode.full,
    this.runningNotificationEnabled = true,
    this.longRunningWarningEnabled = true,
    this.longRunningThresholdHours = 12,
    this.confirmLargeAdjustments = true,
    this.preferredCurrency = 'USD',
    this.clockFormat = ClockFormat.system,
  });

  final ThemeMode themeMode;
  final int firstDayOfWeek;
  final StatRangeType defaultStatRange;
  final DurationDisplayMode durationDisplay;
  final bool runningNotificationEnabled;
  final bool longRunningWarningEnabled;
  final int longRunningThresholdHours;
  final bool confirmLargeAdjustments;
  final String preferredCurrency;
  final ClockFormat clockFormat;

  static const _kTheme = 'themeMode';
  static const _kFirstDay = 'firstDayOfWeek';
  static const _kRange = 'defaultStatRange';
  static const _kDuration = 'durationDisplay';
  static const _kRunningNotif = 'runningNotificationEnabled';
  static const _kWarn = 'longRunningWarningEnabled';
  static const _kThreshold = 'longRunningThresholdHours';
  static const _kConfirmLarge = 'confirmLargeAdjustments';
  static const _kCurrency = 'preferredCurrency';
  static const _kClock = 'clockFormat';

  factory AppSettings.fromMap(Map<String, String> map) {
    T enumFrom<T extends Enum>(List<T> values, String? name, T fallback) {
      if (name == null) return fallback;
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    bool boolFrom(String? v, bool fallback) =>
        v == null ? fallback : v == 'true';
    int intFrom(String? v, int fallback) =>
        v == null ? fallback : (int.tryParse(v) ?? fallback);

    const def = AppSettings();
    return AppSettings(
      themeMode: enumFrom(ThemeMode.values, map[_kTheme], def.themeMode),
      firstDayOfWeek: intFrom(map[_kFirstDay], def.firstDayOfWeek),
      defaultStatRange:
          enumFrom(StatRangeType.values, map[_kRange], def.defaultStatRange),
      durationDisplay: enumFrom(
          DurationDisplayMode.values, map[_kDuration], def.durationDisplay),
      runningNotificationEnabled:
          boolFrom(map[_kRunningNotif], def.runningNotificationEnabled),
      longRunningWarningEnabled:
          boolFrom(map[_kWarn], def.longRunningWarningEnabled),
      longRunningThresholdHours:
          intFrom(map[_kThreshold], def.longRunningThresholdHours),
      confirmLargeAdjustments:
          boolFrom(map[_kConfirmLarge], def.confirmLargeAdjustments),
      preferredCurrency: map[_kCurrency] ?? def.preferredCurrency,
      clockFormat: enumFrom(ClockFormat.values, map[_kClock], def.clockFormat),
    );
  }

  Map<String, String> toMap() => {
        _kTheme: themeMode.name,
        _kFirstDay: firstDayOfWeek.toString(),
        _kRange: defaultStatRange.name,
        _kDuration: durationDisplay.name,
        _kRunningNotif: runningNotificationEnabled.toString(),
        _kWarn: longRunningWarningEnabled.toString(),
        _kThreshold: longRunningThresholdHours.toString(),
        _kConfirmLarge: confirmLargeAdjustments.toString(),
        _kCurrency: preferredCurrency,
        _kClock: clockFormat.name,
      };

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? firstDayOfWeek,
    StatRangeType? defaultStatRange,
    DurationDisplayMode? durationDisplay,
    bool? runningNotificationEnabled,
    bool? longRunningWarningEnabled,
    int? longRunningThresholdHours,
    bool? confirmLargeAdjustments,
    String? preferredCurrency,
    ClockFormat? clockFormat,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      defaultStatRange: defaultStatRange ?? this.defaultStatRange,
      durationDisplay: durationDisplay ?? this.durationDisplay,
      runningNotificationEnabled:
          runningNotificationEnabled ?? this.runningNotificationEnabled,
      longRunningWarningEnabled:
          longRunningWarningEnabled ?? this.longRunningWarningEnabled,
      longRunningThresholdHours:
          longRunningThresholdHours ?? this.longRunningThresholdHours,
      confirmLargeAdjustments:
          confirmLargeAdjustments ?? this.confirmLargeAdjustments,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      clockFormat: clockFormat ?? this.clockFormat,
    );
  }
}
