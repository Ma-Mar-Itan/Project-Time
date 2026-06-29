import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_settings.dart';
import 'core_providers.dart';

/// Reactive settings stream, defaulting to [AppSettings] defaults until loaded.
final settingsStreamProvider = StreamProvider<AppSettings>((ref) {
  return ref
      .watch(databaseProvider)
      .settingsDao
      .watchAll()
      .map(AppSettings.fromMap);
});

/// Synchronous snapshot of settings (defaults while loading).
final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull ?? const AppSettings();
});

/// Persists settings changes back to the database.
final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref);
});

class SettingsController {
  SettingsController(this._ref);
  final Ref _ref;

  Future<void> update(AppSettings settings) async {
    await _ref.read(databaseProvider).settingsDao.putAll(settings.toMap());
  }

  Future<void> mutate(AppSettings Function(AppSettings) change) async {
    final current = _ref.read(settingsProvider);
    await update(change(current));
  }
}
