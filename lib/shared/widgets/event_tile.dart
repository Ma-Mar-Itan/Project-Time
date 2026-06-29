import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/duration_formatter.dart';
import '../../core/utilities/format_utils.dart';
import '../../data/database/app_database.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/enums.dart';

/// Renders a single activity event in a feed (used by global History and the
/// per-project history tab).
class EventTile extends StatelessWidget {
  const EventTile({
    required this.event,
    required this.projectName,
    required this.clockFormat,
    this.showProjectName = true,
    super.key,
  });

  final ActivityEvent event;
  final String projectName;
  final ClockFormat clockFormat;
  final bool showProjectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final (icon, accent) = _visuals(colors, theme.colorScheme.onSurfaceVariant);

    final durationText = _durationText();
    final subtitleParts = <String>[
      event.eventType.label,
      if (durationText != null) durationText,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showProjectName)
                  Text(projectName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: accent),
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    FormatUtils.dateTime(event.occurredAtUtc, clockFormat),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _durationText() {
    final seconds = event.durationSeconds;
    if (seconds == null) return null;
    final duration = Duration(seconds: seconds.abs());
    return switch (event.eventType) {
      EventType.manualAdded => '+${DurationFormatter.compact(duration)}',
      EventType.manualRemoved => '−${DurationFormatter.compact(duration)}',
      _ => DurationFormatter.compact(duration),
    };
  }

  (IconData, Color) _visuals(StatusColors colors, Color neutral) {
    return switch (event.eventType) {
      EventType.timerStarted ||
      EventType.timerResumed =>
        (Icons.play_arrow, colors.running),
      EventType.timerPaused => (Icons.pause, colors.paused),
      EventType.timerStopped => (Icons.stop, neutral),
      EventType.segmentCompleted => (Icons.timer_outlined, colors.running),
      EventType.manualAdded => (Icons.add_circle_outline, colors.running),
      EventType.manualRemoved => (Icons.remove_circle_outline, colors.destructive),
      EventType.projectReset => (Icons.restart_alt, colors.destructive),
      EventType.projectCreated => (Icons.create_outlined, neutral),
      EventType.projectEdited => (Icons.edit_outlined, neutral),
      EventType.projectArchived => (Icons.inventory_2_outlined, neutral),
      EventType.projectRestored => (Icons.unarchive_outlined, neutral),
      EventType.projectDeleted => (Icons.delete_outline, colors.destructive),
      EventType.dataImported => (Icons.download_outlined, neutral),
      EventType.dataExported => (Icons.upload_outlined, neutral),
    };
  }
}
