import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/enums.dart';
import 'core_providers.dart';
import 'project_providers.dart';

/// History feed filter categories (UI-facing groupings of event types).
enum HistoryCategory { all, sessions, additions, removals, resets }

extension HistoryCategoryX on HistoryCategory {
  String get label => switch (this) {
        HistoryCategory.all => 'All',
        HistoryCategory.sessions => 'Sessions',
        HistoryCategory.additions => 'Additions',
        HistoryCategory.removals => 'Removals',
        HistoryCategory.resets => 'Resets',
      };

  Set<EventType>? get eventTypes => switch (this) {
        HistoryCategory.all => null,
        HistoryCategory.sessions => {EventType.segmentCompleted},
        HistoryCategory.additions => {EventType.manualAdded},
        HistoryCategory.removals => {EventType.manualRemoved},
        HistoryCategory.resets => {EventType.projectReset},
      };
}

final historyCategoryProvider =
    StateProvider<HistoryCategory>((ref) => HistoryCategory.all);

/// Null means "all projects".
final historyProjectFilterProvider = StateProvider<String?>((ref) => null);

final historyLimitProvider = StateProvider<int>((ref) => 100);

/// Map of projectId -> project name for rendering the feed.
final projectNameMapProvider = Provider<Map<String, String>>((ref) {
  final projects = ref.watch(allProjectsProvider).valueOrNull ?? const [];
  return {for (final p in projects) p.id: p.name};
});

final historyFeedProvider = StreamProvider<List<ActivityEvent>>((ref) {
  final category = ref.watch(historyCategoryProvider);
  final projectId = ref.watch(historyProjectFilterProvider);
  final limit = ref.watch(historyLimitProvider);
  final db = ref.watch(databaseProvider);

  return db.eventsDao.watchFiltered(
    projectId: projectId,
    eventTypes: category.eventTypes,
    limit: limit,
  );
});
