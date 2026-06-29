import 'package:flutter/material.dart';

import '../../../../core/utilities/duration_formatter.dart';
import '../../../../domain/models/statistics.dart';
import '../../../../shared/widgets/duration_display.dart';

/// A responsive grid of small metric tiles built from [StatsSummary].
class SummaryMetrics extends StatelessWidget {
  const SummaryMetrics({required this.summary, super.key});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = <_MetricTile>[
      _MetricTile.duration(
        label: 'Total tracked',
        duration: Duration(seconds: summary.totalSeconds),
      ),
      _MetricTile.duration(
        label: 'Time today',
        duration: Duration(seconds: summary.todaySeconds),
      ),
      _MetricTile.text(
        label: 'Active projects',
        text: '${summary.activeProjects}',
      ),
      _MetricTile.text(
        label: 'Running now',
        text: '${summary.runningProjects}',
      ),
      _MetricTile.text(
        label: 'Sessions',
        text: '${summary.sessionCount}',
      ),
      _MetricTile.duration(
        label: 'Longest session',
        duration: Duration(seconds: summary.longestSessionSeconds),
      ),
      _MetricTile.duration(
        label: 'Avg / active day',
        duration: Duration(seconds: summary.averagePerActiveDaySeconds),
      ),
      _MetricTile.text(
        label: 'Net manual',
        text: DurationFormatter.signed(
          Duration(seconds: summary.netManualSeconds),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile.text({required this.label, required this.text})
      : duration = null;

  const _MetricTile.duration({required this.label, required this.duration})
      : text = null;

  final String label;
  final String? text;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    final Widget value = duration != null
        ? CompactDuration(duration: duration!, style: valueStyle)
        : Text(text ?? '', style: valueStyle);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          value,
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
