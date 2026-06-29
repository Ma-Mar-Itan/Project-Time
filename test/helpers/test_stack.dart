import 'package:project_time/core/utilities/clock.dart';
import 'package:project_time/data/database/app_database.dart';
import 'package:project_time/domain/services/adjustment_service.dart';
import 'package:project_time/domain/services/export_service.dart';
import 'package:project_time/domain/services/project_service.dart';
import 'package:project_time/domain/services/statistics_service.dart';
import 'package:project_time/domain/services/timer_service.dart';

import 'test_doubles.dart';

/// Bundles an in-memory database, a controllable clock and all services for
/// service-level tests. No real waiting is ever required.
class TestStack {
  TestStack({DateTime? initial})
      : clock = FakeClock(initial ?? DateTime.utc(2026, 1, 1, 12)) {
    db = AppDatabase.forTesting();
    final ids = CounterIdGenerator();
    timer = TimerService(db: db, clock: clock, ids: ids);
    adjustments = AdjustmentService(db: db, clock: clock, ids: ids);
    projects = ProjectService(db: db, clock: clock, ids: ids);
    export = ExportService(db: db, clock: clock);
  }

  late final AppDatabase db;
  final FakeClock clock;
  late final TimerService timer;
  late final AdjustmentService adjustments;
  late final ProjectService projects;
  late final ExportService export;
  final statistics = const StatisticsService();

  Future<String> newProject({String name = 'Project'}) {
    return projects.create(ProjectInput(name: name, colorValue: 0xFF1A73E8));
  }

  Future<int> total(String projectId) =>
      db.timeEntriesDao.completedSecondsForProject(projectId);

  Future<void> dispose() => db.close();
}
