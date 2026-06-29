/// An abstraction over the system clock so timer logic can be tested
/// deterministically without real waiting.
///
/// Production code uses [SystemClock]. Tests inject [FakeClock] and advance it
/// manually. All timer math is expressed against [nowUtc].
abstract class Clock {
  const Clock();

  /// The current instant in UTC. All persisted timestamps use UTC.
  DateTime nowUtc();

  /// The current instant in the device's local timezone (for display only).
  DateTime nowLocal() => nowUtc().toLocal();
}

/// Default clock backed by [DateTime.now].
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Deterministic clock for tests. Advance time with [advance] or [setUtc].
class FakeClock extends Clock {
  FakeClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration delta) => _now = _now.add(delta);

  void setUtc(DateTime value) => _now = value.toUtc();
}
