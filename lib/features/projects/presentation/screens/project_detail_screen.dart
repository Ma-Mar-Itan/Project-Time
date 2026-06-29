import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utilities/duration_formatter.dart';
import '../../../../core/utilities/format_utils.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/models/project_view.dart';
import '../../../../shared/providers/project_providers.dart';
import '../../../../shared/providers/settings_provider.dart';
import '../../../../shared/providers/ticker_provider.dart';
import '../../../../shared/widgets/duration_display.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/event_tile.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../project_actions.dart';
import '../project_detail_providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(singleProjectViewProvider(projectId));

    return viewAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Could not load project: $e'))),
      data: (view) {
        if (view == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: 'Project unavailable',
              message: 'This project may have been deleted.',
            ),
          );
        }
        return _DetailBody(view: view);
      },
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.view});
  final ProjectView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = view.isRunning ? ref.watch(nowProvider) : ref.read(nowProvider);
    final settings = ref.watch(settingsProvider);
    final total = view.totalAt(now);

    final warnThreshold =
        Duration(hours: settings.longRunningThresholdHours);
    final liveSeconds = view.liveSegmentSeconds(now);
    final showWarning = settings.longRunningWarningEnabled &&
        view.isRunning &&
        liveSeconds >= warnThreshold.inSeconds;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(view.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => ProjectActions.edit(context, view),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _onMenu(context, ref, v),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'add', child: Text('Add time')),
                const PopupMenuItem(value: 'remove', child: Text('Remove time')),
                const PopupMenuItem(value: 'reset', child: Text('Reset total')),
                const PopupMenuDivider(),
                if (view.project.isArchived)
                  const PopupMenuItem(value: 'restore', child: Text('Restore'))
                else
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Statistics'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (showWarning) _LongRunningBanner(view: view),
            _TimerHeader(
                view: view,
                total: total,
                now: now,
                clockFormat: settings.clockFormat),
            _ActionRow(view: view),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(projectId: view.id, view: view, now: now),
                  _StatisticsTab(projectId: view.id),
                  _HistoryTab(projectId: view.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenu(BuildContext context, WidgetRef ref, String value) {
    switch (value) {
      case 'add':
        ProjectActions.addTime(context, view);
      case 'remove':
        ProjectActions.removeTime(context, view);
      case 'reset':
        ProjectActions.reset(context, ref, view);
      case 'archive':
        ProjectActions.archive(context, ref, view).then((_) {
          if (context.mounted) context.pop();
        });
      case 'restore':
        ProjectActions.restore(context, ref, view);
      case 'delete':
        ProjectActions.delete(context, ref, view).then((_) {
          if (context.mounted) context.pop();
        });
    }
  }
}

class _TimerHeader extends StatelessWidget {
  const _TimerHeader({
    required this.view,
    required this.total,
    required this.now,
    required this.clockFormat,
  });
  final ProjectView view;
  final Duration total;
  final DateTime now;
  final ClockFormat clockFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          StatusChip(status: view.status),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: FullDurationDisplay(duration: total),
          ),
          const SizedBox(height: 8),
          if (view.isRunning && view.runningStartedAtUtc != null)
            Text(
              'Running since ${FormatUtils.timeOfDay(view.runningStartedAtUtc!, clockFormat)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            Text(
              'Total tracked time',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.view});
  final ProjectView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[];
    switch (view.status) {
      case TimerStatus.stopped:
        buttons.add(_action(Icons.play_arrow, 'Start', true,
            () => ProjectActions.start(ref, view)));
        break;
      case TimerStatus.running:
        buttons.add(_action(Icons.pause, 'Pause', false,
            () => ProjectActions.pause(ref, view)));
        buttons.add(_action(Icons.stop, 'Stop', false,
            () => ProjectActions.stop(context, ref, view)));
        break;
      case TimerStatus.paused:
        buttons.add(_action(Icons.play_arrow, 'Resume', true,
            () => ProjectActions.resume(ref, view)));
        buttons.add(_action(Icons.stop, 'Stop', false,
            () => ProjectActions.stop(context, ref, view)));
        break;
    }
    buttons.add(_action(Icons.add, 'Add', false,
        () => ProjectActions.addTime(context, view)));
    buttons.add(_action(Icons.remove, 'Remove', false,
        () => ProjectActions.removeTime(context, view)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: buttons,
      ),
    );
  }

  Widget _action(
      IconData icon, String label, bool filled, VoidCallback onTap) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
    );
    return filled
        ? FilledButton(onPressed: onTap, child: child)
        : OutlinedButton(onPressed: onTap, child: child);
  }
}

class _LongRunningBanner extends ConsumerWidget {
  const _LongRunningBanner({required this.view});
  final ProjectView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = StatusColors.of(context);
    return MaterialBanner(
      backgroundColor: colors.paused.withValues(alpha: 0.12),
      leading: Icon(Icons.warning_amber_rounded, color: colors.paused),
      content: Text('${view.name} has been running for a long time.'),
      actions: [
        TextButton(
          onPressed: () => ProjectActions.pause(ref, view),
          child: const Text('Pause'),
        ),
        TextButton(
          onPressed: () => ProjectActions.stop(context, ref, view),
          child: const Text('Stop'),
        ),
      ],
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab(
      {required this.projectId, required this.view, required this.now});
  final String projectId;
  final ProjectView view;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(projectDetailStatsProvider(projectId));
    final settings = ref.watch(settingsProvider);
    final p = view.project;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statsAsync.when(
          loading: () => const _StatsGridPlaceholder(),
          error: (e, _) => Text('Stats unavailable: $e'),
          data: (stats) => _SummaryGrid(stats: stats),
        ),
        const SizedBox(height: 16),
        Text('Details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        statsAsync.maybeWhen(
          data: (stats) => Column(
            children: [
              _infoRow(context, 'Timer sessions', '${stats.segmentCount}'),
              _infoRow(context, 'Manual corrections', '${stats.manualCount}'),
              _infoRow(context, 'Longest session',
                  DurationFormatter.compact(
                      Duration(seconds: stats.longestSessionSeconds))),
              _infoRow(context, 'Average session',
                  DurationFormatter.compact(
                      Duration(seconds: stats.averageSessionSeconds))),
              if (p.hourlyRateMinorUnits != null)
                _infoRow(
                  context,
                  'Estimated value',
                  FormatUtils.currency(
                    view.estimatedValueMinorUnits(now) ?? 0,
                    p.currencyCode ?? settings.preferredCurrency,
                  ),
                ),
              _infoRow(context, 'Created',
                  FormatUtils.shortDate(p.createdAtUtc)),
              if (p.lastActivityAtUtc != null)
                _infoRow(context, 'Last active',
                    FormatUtils.shortDate(p.lastActivityAtUtc!)),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.stats});
  final ProjectDetailStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Today', stats.todaySeconds),
      ('This week', stats.weekSeconds),
      ('This month', stats.monthSeconds),
      ('All time', stats.allTimeSeconds),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        for (final c in cards)
          _SummaryCard(label: c.$1, seconds: c.$2),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.seconds});
  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            CompactDuration(
              duration: Duration(seconds: seconds),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGridPlaceholder extends StatelessWidget {
  const _StatsGridPlaceholder();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
}

class _StatisticsTab extends ConsumerWidget {
  const _StatisticsTab({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(projectDetailStatsProvider(projectId));
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Stats unavailable: $e')),
      data: (stats) {
        if (stats.allTimeSeconds == 0 && stats.segmentCount == 0) {
          return const EmptyState(
            icon: Icons.bar_chart,
            title: 'No recorded time yet',
            message: 'Statistics will appear after you record a session.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummaryGrid(stats: stats),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sessions',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text('${stats.segmentCount} timer sessions, '
                        '${stats.manualCount} manual corrections'),
                    const SizedBox(height: 4),
                    Text('Longest: '
                        '${DurationFormatter.compact(Duration(seconds: stats.longestSessionSeconds))} · '
                        'Average: '
                        '${DurationFormatter.compact(Duration(seconds: stats.averageSessionSeconds))}'),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(projectEventsProvider(projectId));
    final settings = ref.watch(settingsProvider);
    final name = ref.watch(projectByIdProvider(projectId)).valueOrNull?.name ??
        'Project';

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('History unavailable: $e')),
      data: (events) {
        if (events.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'No activity yet',
            message: 'Timer activity and corrections will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: events.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
          itemBuilder: (context, index) => EventTile(
            event: events[index],
            projectName: name,
            clockFormat: settings.clockFormat,
            showProjectName: false,
          ),
        );
      },
    );
  }
}
