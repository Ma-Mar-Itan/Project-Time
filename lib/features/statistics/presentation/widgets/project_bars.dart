import 'package:flutter/material.dart';

import '../../../../domain/models/statistics.dart';
import '../../../../shared/widgets/duration_display.dart';

/// A robust, custom horizontal-bar list for time-by-project. Each bar is sized
/// as a fraction of the largest project's seconds. Handles zero-seconds
/// gracefully (renders an empty track).
class ProjectBars extends StatelessWidget {
  const ProjectBars({required this.stats, super.key});

  final List<ProjectTimeStat> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stats.isEmpty) {
      return Text(
        'No project time in this period',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final maxSeconds = stats
        .map((s) => s.seconds)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final stat = stats[index];
          final fraction =
              maxSeconds == 0 ? 0.0 : stat.seconds / maxSeconds;
          return _BarRow(stat: stat, fraction: fraction);
        },
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.stat, required this.fraction});

  final ProjectTimeStat stat;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: stat.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                stat.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            CompactDuration(
              duration: Duration(seconds: stat.seconds),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            color: theme.colorScheme.surfaceContainerHighest,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: stat.color),
            ),
          ),
        ),
      ],
    );
  }
}
