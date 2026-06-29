import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';

/// A small status indicator that conveys state through both an icon + label and
/// color (never color alone), satisfying accessibility guidance.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final TimerStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final (color, icon) = switch (status) {
      TimerStatus.running => (colors.running, Icons.play_arrow),
      TimerStatus.paused => (colors.paused, Icons.pause),
      TimerStatus.stopped => (colors.destructive.withValues(alpha: 0), null),
    };

    final effectiveColor =
        status == TimerStatus.stopped ? Theme.of(context).colorScheme.onSurfaceVariant : color;

    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
            ],
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
