import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/constants/app_constants.dart';

/// Wraps the optional ongoing "running timers" notification. The app stays
/// fully functional if permission is denied — every call is defensively
/// guarded.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || !_isSupported) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    try {
      await _plugin.initialize(settings);
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.ongoingChannelId,
          AppConstants.ongoingChannelName,
          description: 'Shows while project timers are running.',
          importance: Importance.low,
        ),
      );
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.warningChannelId,
          AppConstants.warningChannelName,
          description: 'Warns about timers that have run a long time.',
          importance: Importance.defaultImportance,
        ),
      );
      _initialized = true;
    } catch (e, st) {
      _logError(e, st);
    }
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS permission. Returns true if
  /// granted (or not required). Safe to call repeatedly.
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? true;
    } catch (e, st) {
      _logError(e, st);
      return false;
    }
  }

  /// Updates (or clears) the ongoing notification. Called only when the set of
  /// running timers changes — never on every tick.
  Future<void> updateRunning({
    required int runningCount,
    required List<String> sampleProjectNames,
  }) async {
    if (!_isSupported) return;
    if (runningCount <= 0) {
      await clear();
      return;
    }
    if (!_initialized) await init();

    final names = sampleProjectNames.take(2).join(', ');
    final title = runningCount == 1
        ? '1 project timer is running'
        : '$runningCount project timers are running';
    final body = names.isEmpty ? 'Tap to open Project Time' : names;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.ongoingChannelId,
        AppConstants.ongoingChannelName,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        importance: Importance.low,
        priority: Priority.low,
      ),
    );
    try {
      await _plugin.show(
          AppConstants.ongoingNotificationId, title, body, details);
    } catch (e, st) {
      _logError(e, st);
    }
  }

  Future<void> clear() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(AppConstants.ongoingNotificationId);
    } catch (e, st) {
      _logError(e, st);
    }
  }

  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  void _logError(Object e, StackTrace st) {
    if (kDebugMode) {
      debugPrint('NotificationService error: $e\n$st');
    }
  }
}
