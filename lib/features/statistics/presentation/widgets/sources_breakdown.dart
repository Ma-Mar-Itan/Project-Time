import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/statistics.dart';
import '../../../../shared/widgets/duration_display.dart';

/// Labeled rows showing where tracked time came from: timer, manual additions,
/// manual removals, and the resulting net.
class SourcesBreakdown extends StatelessWidget {
  const SourcesBreakdown({required this.sources, super.key});

  final SourceBreakdown sources;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        _SourceRow(
          label: 'Timer sessions',
          seconds: sources.timerSeconds,
          color: colors.running,
        ),
        const Divider(height: 16),
        _SourceRow(
          label: 'Manual additions',
          seconds: sources.additionSeconds,
          color: theme.colorScheme.primary,
        ),
        const Divider(height: 16),
        _SourceRow(
          label: 'Manual removals',
          seconds: sources.removalSeconds,
          color: colors.destructive,
        ),
        const Divider(height: 16),
        _SourceRow(
          label: 'Net tracked',
          seconds: sources.netSeconds,
          color: theme.colorScheme.onSurface,
          emphasized: true,
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.label,
    required this.seconds,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final int seconds;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasized
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: labelStyle)),
        CompactDuration(
          duration: Duration(seconds: seconds),
          style: labelStyle,
        ),
      ],
    );
  }
}
