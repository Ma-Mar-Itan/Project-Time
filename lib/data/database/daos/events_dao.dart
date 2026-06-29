part of '../app_database.dart';

@DriftAccessor(tables: [ActivityEvents])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  Future<void> insertEvent(ActivityEventsCompanion companion) =>
      into(activityEvents).insert(companion);

  /// Paginated global feed, newest first.
  Stream<List<ActivityEvent>> watchPaged({int limit = 50, int offset = 0}) {
    return (select(activityEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAtUtc)])
          ..limit(limit, offset: offset))
        .watch();
  }

  Stream<List<ActivityEvent>> watchByProject(String projectId,
      {int limit = 200}) {
    return (select(activityEvents)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAtUtc)])
          ..limit(limit))
        .watch();
  }

  /// Filtered feed for the History tab.
  Stream<List<ActivityEvent>> watchFiltered({
    String? projectId,
    Set<EventType>? eventTypes,
    DateTime? startUtc,
    DateTime? endUtc,
    int limit = 100,
    int offset = 0,
  }) {
    final query = select(activityEvents);
    query.where((t) {
      Expression<bool> predicate = const Constant(true);
      if (projectId != null) {
        predicate = predicate & t.projectId.equals(projectId);
      }
      if (eventTypes != null && eventTypes.isNotEmpty) {
        predicate = predicate &
            t.eventType.isIn(eventTypes.map((e) => e.name).toList());
      }
      if (startUtc != null) {
        predicate = predicate & t.occurredAtUtc.isBiggerOrEqualValue(startUtc);
      }
      if (endUtc != null) {
        predicate = predicate & t.occurredAtUtc.isSmallerThanValue(endUtc);
      }
      return predicate;
    });
    query
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAtUtc)])
      ..limit(limit, offset: offset);
    return query.watch();
  }

  Future<void> deleteByProject(String projectId) {
    return (delete(activityEvents)..where((t) => t.projectId.equals(projectId)))
        .go();
  }
}
