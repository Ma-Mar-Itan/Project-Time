import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/app_settings.dart';
import '../../../domain/services/export_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/app_dialogs.dart';

/// The Settings tab: appearance, time display, notifications, data tools and
/// an about section.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          _ThemeModeTiles(current: settings.themeMode),
          const Divider(height: 1),
          const _SectionHeader('Time display'),
          _DurationDisplayTile(current: settings.durationDisplay),
          _FirstDayTile(current: settings.firstDayOfWeek),
          _ClockFormatTile(current: settings.clockFormat),
          const Divider(height: 1),
          const _SectionHeader('Notifications'),
          _NotificationTiles(settings: settings),
          const Divider(height: 1),
          const _SectionHeader('Data'),
          const _DataTiles(),
          const Divider(height: 1),
          const _SectionHeader('About'),
          const _AboutTiles(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --- Appearance ---

class _ThemeModeTiles extends ConsumerWidget {
  const _ThemeModeTiles({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> set(ThemeMode mode) => ref
        .read(settingsControllerProvider)
        .mutate((s) => s.copyWith(themeMode: mode));

    return Column(
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('System'),
          value: ThemeMode.system,
          groupValue: current,
          onChanged: (value) => value == null ? null : set(value),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Light'),
          value: ThemeMode.light,
          groupValue: current,
          onChanged: (value) => value == null ? null : set(value),
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Dark'),
          value: ThemeMode.dark,
          groupValue: current,
          onChanged: (value) => value == null ? null : set(value),
        ),
      ],
    );
  }
}

// --- Time display ---

class _DurationDisplayTile extends ConsumerWidget {
  const _DurationDisplayTile({required this.current});

  final DurationDisplayMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Duration format'),
      subtitle: Text(
        current == DurationDisplayMode.full
            ? 'Full (MO:DD:HH:MM:SS)'
            : 'Compact (4h 32m)',
      ),
      trailing: SegmentedButton<DurationDisplayMode>(
        segments: const [
          ButtonSegment(
            value: DurationDisplayMode.full,
            label: Text('Full'),
          ),
          ButtonSegment(
            value: DurationDisplayMode.compact,
            label: Text('Compact'),
          ),
        ],
        selected: {current},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => ref
            .read(settingsControllerProvider)
            .mutate((s) => s.copyWith(durationDisplay: selection.first)),
      ),
    );
  }
}

class _FirstDayTile extends ConsumerWidget {
  const _FirstDayTile({required this.current});

  final int current;

  static const _days = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('First day of week'),
      trailing: DropdownButton<int>(
        value: current,
        underline: const SizedBox.shrink(),
        items: [
          for (final entry in _days.entries)
            DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        onChanged: (value) => value == null
            ? null
            : ref
                .read(settingsControllerProvider)
                .mutate((s) => s.copyWith(firstDayOfWeek: value)),
      ),
    );
  }
}

class _ClockFormatTile extends ConsumerWidget {
  const _ClockFormatTile({required this.current});

  final ClockFormat current;

  static const _labels = <ClockFormat, String>{
    ClockFormat.system: 'System',
    ClockFormat.h12: '12-hour',
    ClockFormat.h24: '24-hour',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Clock format'),
      trailing: DropdownButton<ClockFormat>(
        value: current,
        underline: const SizedBox.shrink(),
        items: [
          for (final entry in _labels.entries)
            DropdownMenuItem<ClockFormat>(
              value: entry.key,
              child: Text(entry.value),
            ),
        ],
        onChanged: (value) => value == null
            ? null
            : ref
                .read(settingsControllerProvider)
                .mutate((s) => s.copyWith(clockFormat: value)),
      ),
    );
  }
}

// --- Notifications ---

class _NotificationTiles extends ConsumerWidget {
  const _NotificationTiles({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Running timer notification'),
          subtitle: const Text('Show an ongoing notification while tracking.'),
          value: settings.runningNotificationEnabled,
          onChanged: (value) async {
            if (value) {
              await ref
                  .read(notificationServiceProvider)
                  .requestPermission();
            }
            await controller
                .mutate((s) => s.copyWith(runningNotificationEnabled: value));
          },
        ),
        SwitchListTile(
          title: const Text('Long-running warning'),
          subtitle:
              const Text('Warn when a timer has run for a long time.'),
          value: settings.longRunningWarningEnabled,
          onChanged: (value) => controller
              .mutate((s) => s.copyWith(longRunningWarningEnabled: value)),
        ),
        if (settings.longRunningWarningEnabled)
          ListTile(
            title: const Text('Warning threshold'),
            trailing: DropdownButton<int>(
              value: settings.longRunningThresholdHours,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 8, child: Text('8 hours')),
                DropdownMenuItem(value: 12, child: Text('12 hours')),
                DropdownMenuItem(value: 24, child: Text('24 hours')),
              ],
              onChanged: (value) => value == null
                  ? null
                  : controller.mutate(
                      (s) => s.copyWith(longRunningThresholdHours: value)),
            ),
          ),
        SwitchListTile(
          title: const Text('Confirm large adjustments'),
          subtitle: const Text(
            'Ask before applying large manual time corrections.',
          ),
          value: settings.confirmLargeAdjustments,
          onChanged: (value) => controller
              .mutate((s) => s.copyWith(confirmLargeAdjustments: value)),
        ),
      ],
    );
  }
}

// --- Data ---

class _DataTiles extends ConsumerWidget {
  const _DataTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export CSV'),
          subtitle: const Text('Share all time entries as a spreadsheet.'),
          onTap: () => _exportCsv(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Create backup'),
          subtitle: const Text('Export a full JSON backup of all data.'),
          onTap: () => _createBackup(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('Restore backup'),
          subtitle: const Text('Import data from a JSON backup file.'),
          onTap: () => _restoreBackup(context, ref),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Clear all application data',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: const Text('Permanently delete every project and entry.'),
          onTap: () => _clearAll(context, ref),
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final csv = await ref.read(exportServiceProvider).buildCsv();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/project_time_export.csv';
      final file = await File(path).writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (context.mounted) {
        AppDialogs.showSnack(context, 'Export failed: $error');
      }
    }
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(exportServiceProvider).buildBackupJson();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/project_time_backup.json';
      final file = await File(path).writeAsString(json);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (context.mounted) {
        AppDialogs.showSnack(context, 'Backup failed: $error');
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final service = ref.read(exportServiceProvider);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;

      final json = await File(path).readAsString();
      final BackupPreview preview;
      try {
        preview = service.validate(json);
      } on BackupException catch (e) {
        if (context.mounted) AppDialogs.showSnack(context, e.message);
        return;
      }

      if (!context.mounted) return;
      final replaceAll = await _showRestoreDialog(context, preview);
      if (replaceAll == null) return;

      await service.restore(json, replaceAll: replaceAll);
      if (context.mounted) {
        AppDialogs.showSnack(context, 'Backup restored');
      }
    } on BackupException catch (e) {
      if (context.mounted) AppDialogs.showSnack(context, e.message);
    } catch (error) {
      if (context.mounted) {
        AppDialogs.showSnack(context, 'Restore failed: $error');
      }
    }
  }

  /// Returns true (replace all), false (merge), or null (cancelled).
  Future<bool?> _showRestoreDialog(
    BuildContext context,
    BackupPreview preview,
  ) {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Projects: ${preview.projects}'),
              Text('Time entries: ${preview.timeEntries}'),
              Text('Activity events: ${preview.activityEvents}'),
              const SizedBox(height: 12),
              const Text(
                'Replace all wipes existing data first. Merge keeps current '
                'data and adds the backup on top.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Merge'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace all'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final first = await AppDialogs.confirm(
      context,
      title: 'Clear all data?',
      message:
          'This permanently deletes every project, time entry and activity '
          'record. This cannot be undone.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!first || !context.mounted) return;

    final second = await AppDialogs.confirm(
      context,
      title: 'Are you absolutely sure?',
      message:
          'All of your tracked time will be gone forever. Consider creating '
          'a backup first.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!second) return;

    await ref.read(databaseProvider).clearAllData();
    if (context.mounted) {
      AppDialogs.showSnack(context, 'All application data cleared');
    }
  }
}

// --- About ---

class _AboutTiles extends StatelessWidget {
  const _AboutTiles();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? '…'
                : '${info.version}+${info.buildNumber}';
            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              subtitle: Text(version),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Privacy'),
          onTap: () => _showPrivacy(context),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConstants.appName,
          ),
        ),
      ],
    );
  }

  void _showPrivacy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy'),
          content: const Text(
            'All of your data is stored locally on this device. There is no '
            'account, no sign-in, and nothing is sent over the network. '
            'Backups and exports are created only when you choose to share '
            'them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
