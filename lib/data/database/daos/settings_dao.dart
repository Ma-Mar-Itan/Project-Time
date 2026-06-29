part of '../app_database.dart';

@DriftAccessor(tables: [SettingsEntries])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<Map<String, String>> watchAll() {
    return select(settingsEntries).watch().map(
          (rows) => {for (final r in rows) r.key: r.value},
        );
  }

  Future<Map<String, String>> getAll() async {
    final rows = await select(settingsEntries).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> put(String key, String value) {
    return into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(key: key, value: value),
    );
  }

  Future<void> putAll(Map<String, String> values) async {
    await batch((b) {
      for (final entry in values.entries) {
        b.insert(
          settingsEntries,
          SettingsEntriesCompanion.insert(key: entry.key, value: entry.value),
          onConflict: DoUpdate((_) => SettingsEntriesCompanion(
                value: Value(entry.value),
              )),
        );
      }
    });
  }
}
