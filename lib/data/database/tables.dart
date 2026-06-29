import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';

// ---------------------------------------------------------------------------
// Type converters: enums are persisted as their stable `name` string.
// ---------------------------------------------------------------------------

class TimerStatusConverter extends TypeConverter<TimerStatus, String> {
  const TimerStatusConverter();
  @override
  TimerStatus fromSql(String fromDb) => TimerStatus.values.byName(fromDb);
  @override
  String toSql(TimerStatus value) => value.name;
}

class EntryTypeConverter extends TypeConverter<EntryType, String> {
  const EntryTypeConverter();
  @override
  EntryType fromSql(String fromDb) => EntryType.values.byName(fromDb);
  @override
  String toSql(EntryType value) => value.name;
}

class EventTypeConverter extends TypeConverter<EventType, String> {
  const EventTypeConverter();
  @override
  EventType fromSql(String fromDb) => EventType.values.byName(fromDb);
  @override
  String toSql(EventType value) => value.name;
}

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

@TableIndex(name: 'idx_projects_archived', columns: {#isArchived})
@TableIndex(name: 'idx_projects_last_activity', columns: {#lastActivityAtUtc})
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get clientOrCategory => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get colorValue => integer()();
  IntColumn get hourlyRateMinorUnits => integer().nullable()();
  TextColumn get currencyCode => text().nullable()();
  DateTimeColumn get deadlineUtc => dateTime().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  DateTimeColumn get lastActivityAtUtc => dateTime().nullable()();
  DateTimeColumn get archivedAtUtc => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TimerStates extends Table {
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get status =>
      text().map(const TimerStatusConverter())();
  DateTimeColumn get runningStartedAtUtc => dateTime().nullable()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column> get primaryKey => {projectId};
}

@TableIndex(name: 'idx_time_entries_project', columns: {#projectId})
@TableIndex(name: 'idx_time_entries_effective', columns: {#effectiveAtUtc})
@TableIndex(name: 'idx_time_entries_started', columns: {#startedAtUtc})
@TableIndex(name: 'idx_time_entries_type', columns: {#entryType})
class TimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get entryType => text().map(const EntryTypeConverter())();

  /// Signed seconds. Positive for segments/additions/initial time, negative
  /// for removals and reset adjustments. Stored as 64-bit integer.
  IntColumn get signedDurationSeconds => integer()();

  DateTimeColumn get startedAtUtc => dateTime().nullable()();
  DateTimeColumn get endedAtUtc => dateTime().nullable()();

  /// The local-effective instant used for date filtering and stats allocation.
  DateTimeColumn get effectiveAtUtc => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime().nullable()();
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_events_project', columns: {#projectId})
@TableIndex(name: 'idx_events_occurred', columns: {#occurredAtUtc})
@TableIndex(name: 'idx_events_type', columns: {#eventType})
class ActivityEvents extends Table {
  TextColumn get id => text()();

  /// Nullable so a global "project deleted" audit event can survive after the
  /// project row is removed.
  TextColumn get projectId =>
      text().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();
  TextColumn get eventType => text().map(const EventTypeConverter())();
  DateTimeColumn get occurredAtUtc => dateTime()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key-value settings store.
class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
