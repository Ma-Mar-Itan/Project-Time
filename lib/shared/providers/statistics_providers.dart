import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/date_range_utils.dart';
import '../../domain/models/statistics.dart';
import 'core_providers.dart';
import 'project_providers.dart';
import 'settings_provider.dart';

final statsRangeTypeProvider = StateProvider<StatRangeType>((ref) {
  return ref.read(settingsProvider).defaultStatRange;
});

/// (start, end) for a custom range; both null until chosen.
final statsCustomRangeProvider =
    StateProvider<(DateTime?, DateTime?)>((ref) => (null, null));

/// Computes statistics for the selected range, recomputing whenever the
/// underlying time data changes.
final statisticsResultProvider = FutureProvider<StatisticsResult>((ref) async {
  // Establish reactive dependencies on the underlying data.
  ref.watch(projectTotalsProvider);
  ref.watch(allTimerStatesProvider);
  ref.watch(allProjectsProvider);

  final type = ref.watch(statsRangeTypeProvider);
  final custom = ref.watch(statsCustomRangeProvider);
  final settings = ref.watch(settingsProvider);

  final clock = ref.read(clockProvider);
  final db = ref.read(databaseProvider);
  final service = ref.read(statisticsServiceProvider);

  final range = DateRangeUtils.resolve(
    type,
    nowLocal: clock.nowLocal(),
    firstDayOfWeek: settings.firstDayOfWeek,
    customStart: custom.$1,
    customEnd: custom.$2,
  );
  final unit = DateRangeUtils.bucketUnitFor(type);

  return service.computeFromDatabase(
    db: db,
    clock: clock,
    range: range,
    bucketUnit: unit,
  );
});
