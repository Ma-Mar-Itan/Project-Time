import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/statistics.dart';

/// A line chart of hours tracked per bucket. Every bucket is already present
/// (zeros included) so the line is continuous without interpolating gaps.
class OverTimeChart extends StatelessWidget {
  const OverTimeChart({required this.buckets, super.key});

  final List<TimeBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (buckets.isEmpty) {
      return Text(
        'No data in this period',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < buckets.length; i++)
        FlSpot(i.toDouble(), buckets[i].seconds / 3600),
    ];
    final maxY = spots
        .map((s) => s.y)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final niceMaxY = maxY <= 0 ? 1.0 : maxY * 1.2;

    return RepaintBoundary(
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (buckets.length - 1).toDouble(),
            minY: 0,
            maxY: niceMaxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      '${value.toStringAsFixed(0)}h',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: theme.colorScheme.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
