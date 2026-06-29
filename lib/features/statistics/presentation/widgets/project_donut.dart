import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/statistics.dart';

/// A donut chart of project share. Each slice uses its [DonutSlice.color] and
/// shows the percentage. Renders a note when there is no data.
class ProjectDonut extends StatelessWidget {
  const ProjectDonut({required this.slices, super.key});

  final List<DonutSlice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slices.isEmpty) {
      return Text(
        'No data in this period',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return RepaintBoundary(
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: [
                  for (final slice in slices)
                    PieChartSectionData(
                      value: slice.fraction * 100,
                      color: slice.color,
                      radius: 30,
                      title: slice.fraction >= 0.08
                          ? '${(slice.fraction * 100).round()}%'
                          : '',
                      titleStyle: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _Legend(slices: slices)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices});

  final List<DonutSlice> slices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slice.label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(slice.fraction * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
