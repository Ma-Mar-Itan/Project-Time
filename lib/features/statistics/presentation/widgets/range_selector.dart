import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/date_range_utils.dart';
import '../../../../shared/providers/statistics_providers.dart';

/// Horizontal scrolling row of [ChoiceChip]s bound to [statsRangeTypeProvider].
/// Selecting "Custom" opens a date range picker and stores the result.
class RangeSelector extends ConsumerWidget {
  const RangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statsRangeTypeProvider);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: StatRangeType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = StatRangeType.values[index];
          return ChoiceChip(
            label: Text(type.label),
            selected: selected == type,
            onSelected: (_) => _onSelected(context, ref, type),
          );
        },
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    StatRangeType type,
  ) async {
    if (type == StatRangeType.custom) {
      final now = DateTime.now();
      final existing = ref.read(statsCustomRangeProvider);
      final initialRange = existing.$1 != null && existing.$2 != null
          ? DateTimeRange(start: existing.$1!, end: existing.$2!)
          : null;
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime(now.year + 1, now.month, now.day),
        initialDateRange: initialRange,
      );
      if (picked != null) {
        ref.read(statsCustomRangeProvider.notifier).state =
            (picked.start, picked.end);
        ref.read(statsRangeTypeProvider.notifier).state = StatRangeType.custom;
      }
      return;
    }
    ref.read(statsRangeTypeProvider.notifier).state = type;
  }
}
