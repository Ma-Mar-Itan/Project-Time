/// Central place for app-wide constants.
///
/// To rebrand the app, change [appName] here and the `applicationId` /
/// `namespace` in `android/app/build.gradle.kts` and the `android:label`
/// in `android/app/src/main/AndroidManifest.xml`.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Project Time';
  static const String databaseFileName = 'project_time.sqlite';
  static const String backupFileExtension = 'json';

  /// One elapsed "month" is defined as exactly 30 days for duration display.
  static const int daysPerDisplayMonth = 30;
  static const int secondsPerMinute = 60;
  static const int secondsPerHour = 3600;
  static const int secondsPerDay = 86400;
  static const int secondsPerDisplayMonth =
      daysPerDisplayMonth * secondsPerDay; // 2,592,000

  /// Notification channel for the ongoing running-timer notification.
  static const String ongoingChannelId = 'project_time_ongoing';
  static const String ongoingChannelName = 'Running timers';
  static const String warningChannelId = 'project_time_warnings';
  static const String warningChannelName = 'Long-running timer warnings';
  static const int ongoingNotificationId = 1001;

  /// Animation timing budget (Material-restrained).
  static const Duration shortAnimation = Duration(milliseconds: 180);
  static const Duration mediumAnimation = Duration(milliseconds: 240);

  /// Rounded-corner radius used across cards and sheets.
  static const double cardRadius = 14;
  static const double minTouchTarget = 48;

  /// JSON backup schema version. Bump when the export format changes.
  static const int backupSchemaVersion = 1;
}
