import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/duration_formatter.dart';
import '../../../../core/utilities/format_utils.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/models/project_view.dart';
import '../../../../shared/providers/settings_provider.dart';
import '../../../../shared/providers/ticker_provider.dart';
import '../../../../shared/widgets/duration_display.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../project_actions.dart';

enum _MenuAction {
  open,
  addTime,
  removeTime,
  edit,
  reset,
  archive,
  restore,
  delete,
}

/// A single project row in the Projects list. Updates live each second while
/// running (driven by the shared ticker).
class ProjectCard extends ConsumerWidget {
  const ProjectCard({required this.view, super.key});

  final ProjectView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = view.isRunning ? ref.watch(nowProvider) : ref.read(nowProvider);
    final settings = ref.watch(settingsProvider);
    final total = view.totalAt(now);
    final theme = Theme.of(context);

    final subtitle = view.project.clientOrCategory ?? view.project.description;
    final lastActivity = view.project.lastActivityAtUtc;

    return Semantics(
      label: '${view.name}, ${view.status.label}, '
          'total time ${DurationFormatter.spoken(total)}',
      child: Card(
        child: InkWell(
          onTap: () => ProjectActions.open(context, view),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 3, right: 12),
                      decoration: BoxDecoration(
                        color: view.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            view.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildMenu(context, ref),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    StatusChip(status: view.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FullDurationDisplay(duration: total, compact: true),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (lastActivity != null)
                      Text(
                        FormatUtils.relativeFromNow(lastActivity, now: now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    ..._buildActions(context, ref),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    switch (view.status) {
      case TimerStatus.running:
        return [
          _SmallButton(
            icon: Icons.pause,
            label: 'Pause',
            onPressed: () => ProjectActions.pause(ref, view),
          ),
          const SizedBox(width: 4),
          _SmallButton(
            icon: Icons.stop,
            label: 'Stop',
            onPressed: () => ProjectActions.stop(context, ref, view),
          ),
        ];
      case TimerStatus.paused:
        return [
          _SmallButton(
            icon: Icons.play_arrow,
            label: 'Resume',
            onPressed: () => ProjectActions.resume(ref, view),
          ),
          const SizedBox(width: 4),
          _SmallButton(
            icon: Icons.stop,
            label: 'Stop',
            onPressed: () => ProjectActions.stop(context, ref, view),
          ),
        ];
      case TimerStatus.stopped:
        return [
          _SmallButton(
            icon: Icons.play_arrow,
            label: 'Start',
            filled: true,
            onPressed: () => ProjectActions.start(ref, view),
          ),
        ];
    }
  }

  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    final archived = view.project.isArchived;
    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More actions',
      onSelected: (action) => _onMenu(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(value: _MenuAction.open, child: Text('Open project')),
        const PopupMenuItem(value: _MenuAction.addTime, child: Text('Add time')),
        const PopupMenuItem(
            value: _MenuAction.removeTime, child: Text('Remove time')),
        const PopupMenuItem(value: _MenuAction.edit, child: Text('Edit project')),
        const PopupMenuItem(value: _MenuAction.reset, child: Text('Reset total')),
        const PopupMenuDivider(),
        if (archived)
          const PopupMenuItem(
              value: _MenuAction.restore, child: Text('Restore'))
        else
          const PopupMenuItem(
              value: _MenuAction.archive, child: Text('Archive')),
        const PopupMenuItem(value: _MenuAction.delete, child: Text('Delete')),
      ],
    );
  }

  void _onMenu(BuildContext context, WidgetRef ref, _MenuAction action) {
    switch (action) {
      case _MenuAction.open:
        ProjectActions.open(context, view);
      case _MenuAction.addTime:
        ProjectActions.addTime(context, view);
      case _MenuAction.removeTime:
        ProjectActions.removeTime(context, view);
      case _MenuAction.edit:
        ProjectActions.edit(context, view);
      case _MenuAction.reset:
        ProjectActions.reset(context, ref, view);
      case _MenuAction.archive:
        ProjectActions.archive(context, ref, view);
      case _MenuAction.restore:
        ProjectActions.restore(context, ref, view);
      case _MenuAction.delete:
        ProjectActions.delete(context, ref, view);
    }
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(label)],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: filled
          ? FilledButton.tonal(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: child,
            ),
    );
  }
}
