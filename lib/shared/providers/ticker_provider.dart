import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import 'project_providers.dart';

/// A single shared one-second ticker for all live timer displays.
///
/// It only ticks while at least one timer is running; when nothing is running
/// it emits once and stops, avoiding wasteful rebuilds. The emitted value is
/// the current UTC instant — the authoritative elapsed time is computed from
/// persisted timestamps, never accumulated here.
final tickerProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  final running = ref.watch(runningCountProvider);

  yield clock.nowUtc();
  if (running > 0) {
    yield* Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => clock.nowUtc(),
    );
  }
});

/// Convenience to read "now" for live displays without forcing a watch error.
final nowProvider = Provider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return ref.watch(tickerProvider).valueOrNull ?? clock.nowUtc();
});
