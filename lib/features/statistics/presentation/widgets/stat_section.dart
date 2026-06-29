import 'package:flutter/material.dart';

/// A titled card section used to group a single statistics visualization.
class StatSection extends StatelessWidget {
  const StatSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Spacing helper used between sections so the constructor list stays const.
class SectionGap extends StatelessWidget {
  const SectionGap({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: 12);
}
