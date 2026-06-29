import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/clock.dart';
import '../../data/database/app_database.dart';
import '../../domain/services/adjustment_service.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/id_generator.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/project_service.dart';
import '../../domain/services/statistics_service.dart';
import '../../domain/services/timer_service.dart';

/// Overridden in `main()` (and tests) with a concrete database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidGenerator());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final timerServiceProvider = Provider<TimerService>((ref) {
  return TimerService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});

final adjustmentServiceProvider = Provider<AdjustmentService>((ref) {
  return AdjustmentService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  );
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final statisticsServiceProvider =
    Provider<StatisticsService>((ref) => const StatisticsService());
