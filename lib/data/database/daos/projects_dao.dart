part of '../app_database.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  /// Active (not archived, not soft-deleted) projects.
  Stream<List<Project>> watchActive() {
    return (select(projects)
          ..where((t) => t.isArchived.equals(false) & t.deletedAtUtc.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.lastActivityAtUtc),
            (t) => OrderingTerm.desc(t.createdAtUtc),
          ]))
        .watch();
  }

  /// Archived (but not deleted) projects.
  Stream<List<Project>> watchArchived() {
    return (select(projects)
          ..where((t) => t.isArchived.equals(true) & t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.archivedAtUtc)]))
        .watch();
  }

  /// All non-deleted projects (includes archived) — used by statistics.
  Stream<List<Project>> watchAllIncludingArchived() {
    return (select(projects)..where((t) => t.deletedAtUtc.isNull())).watch();
  }

  Future<List<Project>> getAllIncludingArchived() {
    return (select(projects)..where((t) => t.deletedAtUtc.isNull())).get();
  }

  Stream<Project?> watchById(String id) {
    return (select(projects)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Project?> getById(String id) {
    return (select(projects)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertProject(ProjectsCompanion companion) =>
      into(projects).insert(companion);

  Future<void> updateProject(ProjectsCompanion companion) =>
      (update(projects)..where((t) => t.id.equals(companion.id.value)))
          .write(companion);

  Future<int> countActive() async {
    final count = projects.id.count();
    final q = selectOnly(projects)
      ..addColumns([count])
      ..where(projects.isArchived.equals(false) & projects.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }
}
