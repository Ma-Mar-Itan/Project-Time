/// The lifecycle state of a project's timer.
enum TimerStatus { stopped, running, paused }

extension TimerStatusX on TimerStatus {
  String get label => switch (this) {
        TimerStatus.stopped => 'Stopped',
        TimerStatus.running => 'Running',
        TimerStatus.paused => 'Paused',
      };

  bool get isRunning => this == TimerStatus.running;
  bool get isPaused => this == TimerStatus.paused;
  bool get isStopped => this == TimerStatus.stopped;
}

/// The kind of a [TimeEntry]. The sign of `signedDurationSeconds` is enforced
/// per type (segments/additions positive, removals/resets negative).
enum EntryType {
  timerSegment,
  manualAddition,
  manualRemoval,
  resetAdjustment,
  initialTime,
  importedAdjustment,
}

extension EntryTypeX on EntryType {
  String get label => switch (this) {
        EntryType.timerSegment => 'Timer session',
        EntryType.manualAddition => 'Manual addition',
        EntryType.manualRemoval => 'Manual removal',
        EntryType.resetAdjustment => 'Reset',
        EntryType.initialTime => 'Initial time',
        EntryType.importedAdjustment => 'Imported',
      };

  bool get isManual =>
      this == EntryType.manualAddition || this == EntryType.manualRemoval;
}

/// Append-only activity log event types.
enum EventType {
  projectCreated,
  projectEdited,
  timerStarted,
  timerPaused,
  timerResumed,
  timerStopped,
  segmentCompleted,
  manualAdded,
  manualRemoved,
  projectReset,
  projectArchived,
  projectRestored,
  projectDeleted,
  dataImported,
  dataExported,
}

extension EventTypeX on EventType {
  String get label => switch (this) {
        EventType.projectCreated => 'Project created',
        EventType.projectEdited => 'Project edited',
        EventType.timerStarted => 'Timer started',
        EventType.timerPaused => 'Timer paused',
        EventType.timerResumed => 'Timer resumed',
        EventType.timerStopped => 'Timer stopped',
        EventType.segmentCompleted => 'Session completed',
        EventType.manualAdded => 'Manual time added',
        EventType.manualRemoved => 'Manual time removed',
        EventType.projectReset => 'Project reset',
        EventType.projectArchived => 'Project archived',
        EventType.projectRestored => 'Project restored',
        EventType.projectDeleted => 'Project deleted',
        EventType.dataImported => 'Data imported',
        EventType.dataExported => 'Data exported',
      };
}
