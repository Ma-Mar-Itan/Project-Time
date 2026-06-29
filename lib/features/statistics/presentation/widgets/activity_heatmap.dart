import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utilities/duration_formatter.dart';
import '../../../../domain/models/statistics.dart';

/// A custom contribution-graph-style heatmap. Days are laid out in columns of
/// seven (one column per week, weekday rows top-to-bottom). Color intensity
/// scales with tracked seconds. Horizontally scrollable.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({required this.days, super.key});

  final List<DayHeat> days;

  static const double _cell = 14;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (days.isEmpty) {
      return Text(
        'No data in this period',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final running = StatusColors.of(context).running;
    final emptyColor = theme.colorScheme.surfaceContainerHighest;
    final maxSeconds = days
        .map((d) => d.seconds)
        .fold<int>(0, (a, b) => a > b ? a : b);

    // Build week columns. Pad the first column so weekday alignment is
    // consistent (Monday at the top => weekday 1 maps to row 0).
    final columns = <List<DayHeat?>>[];
    var current = <DayHeat?>[];
    for (final day in days) {
      final weekdayIndex = (day.day.weekday - DateTime.monday + 7) % 7;
      if (current.isEmpty && weekdayIndex > 0) {
        for (var i = 0; i < weekdayIndex; i++) {
          current.add(null);
        }
      }
      current.add(day);
      if (current.length == 7) {
        columns.add(current);
        current = <DayHeat?>[];
      }
    }
    if (current.isNotEmpty) {
      while (current.length < 7) {
        current.add(null);
      }
      columns.add(current);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in columns)
            Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: Column(
                children: [
                  for (final day in column)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: _Cell(
                        day: day,
                        color: day == null
                            ? Colors.transparent
                            : _colorFor(
                                day.seconds, maxSeconds, running, emptyColor),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _colorFor(
    int seconds,
    int maxSeconds,
    Color running,
    Color emptyColor,
  ) {
    if (seconds <= 0 || maxSeconds <= 0) return emptyColor;
    final ratio = seconds / maxSeconds;
    final double alpha;
    if (ratio <= 0.25) {
      alpha = 0.3;
    } else if (ratio <= 0.5) {
      alpha = 0.5;
    } else if (ratio <= 0.75) {
      alpha = 0.75;
    } else {
      alpha = 1.0;
    }
    return running.withValues(alpha: alpha);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.day, required this.color});

  final DayHeat? day;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: ActivityHeatmap._cell,
      height: ActivityHeatmap._cell,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    if (day == null) return box;
    final dateLabel = DateFormat('d MMM yyyy').format(day!.day);
    final durationLabel =
        DurationFormatter.compact(Duration(seconds: day!.seconds));
    return Tooltip(
      message: '$dateLabel · $durationLabel',
      child: box,
    );
  }
}
