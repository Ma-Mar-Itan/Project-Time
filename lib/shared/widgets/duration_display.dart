import 'package:flutter/material.dart';

import '../../core/utilities/duration_formatter.dart';

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// The large MO:DD:HH:MM:SS timer display with unit labels underneath.
/// Uses tabular figures so digits don't shift as they tick.
class FullDurationDisplay extends StatelessWidget {
  const FullDurationDisplay({
    required this.duration,
    this.compact = false,
    super.key,
  });

  final Duration duration;

  /// When true, renders a smaller variant (e.g. inside list cards).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = DurationComponents.fromDuration(duration);
    final theme = Theme.of(context);
    final numberStyle = (compact
            ? theme.textTheme.titleLarge
            : theme.textTheme.displaySmall)
        ?.merge(_tabular)
        .copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.5,
    );

    final cells = <Widget>[
      _cell(c.months.toString().padLeft(2, '0'), 'MO', numberStyle, labelStyle),
      _separator(numberStyle),
      _cell(_two(c.days), 'DD', numberStyle, labelStyle),
      _separator(numberStyle),
      _cell(_two(c.hours), 'HH', numberStyle, labelStyle),
      _separator(numberStyle),
      _cell(_two(c.minutes), 'MM', numberStyle, labelStyle),
      _separator(numberStyle),
      _cell(_two(c.seconds), 'SS', numberStyle, labelStyle),
    ];

    return Semantics(
      label: DurationFormatter.spoken(duration),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cells,
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  Widget _cell(String value, String label, TextStyle? n, TextStyle? l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: n),
        const SizedBox(height: 2),
        Text(label, style: l),
      ],
    );
  }

  Widget _separator(TextStyle? n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(':', style: n?.copyWith(fontWeight: FontWeight.w400)),
    );
  }
}

/// Compact, accessible single-line duration (e.g. "2mo 14d").
class CompactDuration extends StatelessWidget {
  const CompactDuration({required this.duration, this.style, super.key});

  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: DurationFormatter.spoken(duration),
      excludeSemantics: true,
      child: Text(
        DurationFormatter.compact(duration),
        style: (style ?? const TextStyle()).merge(_tabular),
      ),
    );
  }
}
