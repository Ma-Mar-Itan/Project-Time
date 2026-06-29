import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utilities/duration_formatter.dart';
import '../../../domain/models/project_view.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/ticker_provider.dart';
import '../../../shared/widgets/app_dialogs.dart';
import 'widgets/adjust_time_sheet.dart';

/// Centralized project action handlers shared by the list cards and the detail
/// screen, so behavior (confirmations, snackbars) stays consistent.
class ProjectActions {
  const ProjectActions._();

  static Future<void> start(WidgetRef ref, ProjectView p) async {
    HapticFeedback.selectionClick();
    await ref.read(timerServiceProvider).start(p.id);
  }

  static Future<void> pause(WidgetRef ref, ProjectView p) async {
    HapticFeedback.selectionClick();
    await ref.read(timerServiceProvider).pause(p.id);
  }

  static Future<void> resume(WidgetRef ref, ProjectView p) async {
    HapticFeedback.selectionClick();
    await ref.read(timerServiceProvider).resume(p.id);
  }

  static Future<void> stop(BuildContext context, WidgetRef ref,
      ProjectView p) async {
    HapticFeedback.selectionClick();
    await ref.read(timerServiceProvider).stop(p.id);
    if (context.mounted) AppDialogs.showSnack(context, 'Timer stopped');
  }

  static void open(BuildContext context, ProjectView p) {
    context.push(Routes.projectDetail(p.id));
  }

  static void edit(BuildContext context, ProjectView p) {
    context.push(Routes.editProject(p.id));
  }

  static Future<void> addTime(
      BuildContext context, ProjectView p) async {
    await AdjustTimeSheet.show(context, project: p, isAddition: true);
  }

  static Future<void> removeTime(
      BuildContext context, ProjectView p) async {
    await AdjustTimeSheet.show(context, project: p, isAddition: false);
  }

  static Future<void> reset(
      BuildContext context, WidgetRef ref, ProjectView p) async {
    final now = ref.read(clockProvider).nowUtc();
    final total = p.totalAt(now);
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset total?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset "${p.name}" to zero? Previous activity will remain '
              'visible in the history.',
            ),
            const SizedBox(height: 12),
            Text('Current total: ${DurationFormatter.compact(total)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      await ref.read(adjustmentServiceProvider).resetTotal(
            p.id,
            reason: reason.isEmpty ? null : reason,
          );
      if (context.mounted) AppDialogs.showSnack(context, 'Project reset to zero');
    }
    reasonController.dispose();
  }

  static Future<void> archive(
      BuildContext context, WidgetRef ref, ProjectView p) async {
    final message = p.isRunning
        ? '"${p.name}" is running. Archiving will stop the timer and hide the '
            'project from the list. Its data is kept.'
        : 'Archive "${p.name}"? It will be hidden from the list but its data '
            'is kept and can be restored.';
    final ok = await AppDialogs.confirm(
      context,
      title: 'Archive project?',
      message: message,
      confirmLabel: 'Archive',
    );
    if (!ok) return;
    await ref.read(projectServiceProvider).archive(p.id);
    if (context.mounted) {
      AppDialogs.showSnack(
        context,
        'Project archived',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(projectServiceProvider).restore(p.id),
        ),
      );
    }
  }

  static Future<void> restore(
      BuildContext context, WidgetRef ref, ProjectView p) async {
    await ref.read(projectServiceProvider).restore(p.id);
    if (context.mounted) AppDialogs.showSnack(context, 'Project restored');
  }

  static Future<void> delete(
      BuildContext context, WidgetRef ref, ProjectView p) async {
    final now = ref.read(clockProvider).nowUtc();
    final hasHistory = p.totalAt(now).inSeconds > 0;

    final ok = await AppDialogs.confirm(
      context,
      title: 'Delete project?',
      message:
          'Permanently delete "${p.name}"? Its timer history and corrections '
          'will be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;

    if (hasHistory) {
      final secondConfirm = await AppDialogs.confirm(
        context,
        title: 'Are you sure?',
        message:
            '"${p.name}" has tracked time. Deleting removes all of its records '
            'permanently.',
        confirmLabel: 'Delete permanently',
        destructive: true,
      );
      if (!secondConfirm) return;
    }

    await ref.read(projectServiceProvider).delete(p.id);
    if (context.mounted) AppDialogs.showSnack(context, 'Project deleted');
  }

  /// Pauses all running timers, with confirmation when more than one is active.
  static Future<void> pauseAll(
      BuildContext context, WidgetRef ref, int runningCount) async {
    if (runningCount > 1) {
      final ok = await AppDialogs.confirm(
        context,
        title: 'Pause all timers?',
        message: 'This will pause $runningCount running timers.',
        confirmLabel: 'Pause all',
      );
      if (!ok) return;
    }
    final count = await ref.read(timerServiceProvider).pauseAll();
    if (context.mounted) {
      AppDialogs.showSnack(context, 'Paused $count timer${count == 1 ? '' : 's'}');
    }
  }
}

/// Reads the live "now" for screens that show running totals.
DateTime watchNow(WidgetRef ref) => ref.watch(nowProvider);
