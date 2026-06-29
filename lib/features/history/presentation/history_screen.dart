import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utilities/format_utils.dart';
import '../../../data/database/app_database.dart';
import '../../../shared/providers/history_providers.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/event_tile.dart';

/// The History tab: a filterable, day-grouped feed of activity events.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(historyCategoryProvider);
    final feedAsync = ref.watch(historyFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          _CategoryFilter(selected: category),
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Something went wrong: $error'),
                ),
              ),
              data: (events) => _HistoryFeed(events: events),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter({required this.selected});

  final HistoryCategory selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: HistoryCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = HistoryCategory.values[index];
          return ChoiceChip(
            label: Text(category.label),
            selected: selected == category,
            onSelected: (_) => ref
                .read(historyCategoryProvider.notifier)
                .state = category,
          );
        },
      ),
    );
  }
}

class _HistoryFeed extends ConsumerWidget {
  const _HistoryFeed({required this.events});

  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No activity yet',
        message:
            'Timer activity and manual corrections will appear here.',
      );
    }

    final nameMap = ref.watch(projectNameMapProvider);
    final clockFormat = ref.watch(settingsProvider).clockFormat;
    final limit = ref.watch(historyLimitProvider);

    final rows = _buildRows(events);
    final canLoadMore = events.length >= limit;

    return ListView.builder(
      itemCount: rows.length + (canLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return _LoadMoreButton(
            onPressed: () => ref
                .read(historyLimitProvider.notifier)
                .update((value) => value + 100),
          );
        }
        final row = rows[index];
        if (row is _HeaderRow) {
          return _DayHeader(label: row.label);
        }
        final eventRow = row as _EventRow;
        final event = eventRow.event;
        final projectName = event.projectId == null
            ? (event.note ?? 'Project')
            : (nameMap[event.projectId] ?? 'Project');
        return EventTile(
          event: event,
          projectName: projectName,
          clockFormat: clockFormat,
        );
      },
    );
  }

  /// Flattens the event list into interleaved day-header and event rows.
  List<_FeedRow> _buildRows(List<ActivityEvent> events) {
    final rows = <_FeedRow>[];
    DateTime? lastDay;
    for (final event in events) {
      final local = event.occurredAtUtc.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay == null || day != lastDay) {
        rows.add(_HeaderRow(_dayLabel(day, event.occurredAtUtc)));
        lastDay = day;
      }
      rows.add(_EventRow(event));
    }
    return rows;
  }

  String _dayLabel(DateTime localDay, DateTime occurredAtUtc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (localDay == today) return 'Today';
    if (localDay == yesterday) return 'Yesterday';
    return FormatUtils.dayMonthYear(occurredAtUtc);
  }
}

abstract class _FeedRow {
  const _FeedRow();
}

class _HeaderRow extends _FeedRow {
  const _HeaderRow(this.label);
  final String label;
}

class _EventRow extends _FeedRow {
  const _EventRow(this.event);
  final ActivityEvent event;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: onPressed,
          child: const Text('Load more'),
        ),
      ),
    );
  }
}
