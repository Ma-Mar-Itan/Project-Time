import 'package:flutter/material.dart';

import '../../../../core/utilities/format_utils.dart';
import '../../../../domain/models/statistics.dart';
import '../../../../shared/widgets/duration_display.dart';

/// A compact list of the longest completed timer sessions.
class LongestSessionsList extends StatelessWidget {
  const LongestSessionsList({required this.sessions, super.key});

  final List<SessionStat> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (sessions.isEmpty) {
      return Text(
        'No completed sessions yet',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const Divider(height: 16),
          _SessionRow(session: sessions[i]),
        ],
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final SessionStat session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: session.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.projectName,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                FormatUtils.shortDate(session.startedAtUtc),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CompactDuration(
          duration: Duration(seconds: session.seconds),
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
