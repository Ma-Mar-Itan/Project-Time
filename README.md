# Project Time

A local-first, offline, multi-project time tracker for Android, built with Flutter and Material 3. Create projects, run several timers at once, correct time manually, and explore statistics — all stored on-device with **no account, no network, and no analytics**.

---

## Highlights

- **Multiple concurrent timers** — run, pause, resume, and stop any number of project timers independently.
- **Timestamp-based truth** — elapsed time is derived from a persisted UTC start timestamp, never from a background counter. Timers stay accurate across app close, process death, and device reboot.
- **`MO : DD : HH : MM : SS`** long-duration display (30-day months), plus compact forms like `2mo 14d`.
- **Manual corrections** — add or remove time, with an immutable, signed audit trail. Removals can never push a total below zero.
- **Reset without data loss** — resetting writes a negative adjustment and keeps full history.
- **Statistics** — time by project, time over time, project share donut, an activity heatmap, timer-vs-manual breakdown, and longest sessions, across selectable date ranges.
- **History** — a chronological, filterable activity log.
- **CSV export & JSON backup/restore** — with CSV formula-injection protection.
- **Light / dark / system themes**, accessibility semantics, and a responsive layout (bottom nav on phones, navigation rail on tablets/foldables).

---

## Tech stack

| Concern | Choice | Why |
|---|---|---|
| State management | `flutter_riverpod` | Testable, compile-safe providers; a single shared 1-second ticker drives all live displays. |
| Database | `drift` + `sqlite3_flutter_libs` | Type-safe SQLite with migrations, indexes, foreign keys, and reactive streams. |
| Navigation | `go_router` | Declarative routing with a stateful bottom-nav shell. |
| Charts | `fl_chart` | Maintained, flexible Flutter charting. |
| Files / sharing | `file_picker`, `share_plus`, `path_provider` | Backup/restore and CSV export via the system share sheet (no broad storage permissions). |
| Notifications | `flutter_local_notifications` | Optional ongoing "timers running" notification. |
| Misc | `uuid`, `intl`, `package_info_plus` | IDs, formatting, app version. |

> **Versions:** `pubspec.yaml` pins conservative lower bounds. Because this was authored offline, run `flutter pub upgrade --major-versions` once to move to the current published versions for your installed Flutter, then `flutter pub get`.

---

## Project structure

```
lib/
  main.dart                 # entry point; opens DB, overrides databaseProvider
  app.dart                  # MaterialApp.router, theming, notification sync
  core/
    constants/              # AppConstants (app name, channels, radii…)
    routing/                # go_router config + Routes
    theme/                  # Material 3 light/dark themes, palette, StatusColors
    utilities/              # DurationFormatter, DateRangeUtils, TimeEntrySplitter,
                            # Clock, CsvUtils, FormatUtils
  data/
    database/
      app_database.dart     # Drift DB, migrations, connection
      tables.dart           # tables + enum TypeConverters + indexes
      daos/                 # projects/timer/time_entries/events/settings DAOs
  domain/
    models/                 # enums, ProjectView, AppSettings, statistics models
    services/               # timer, adjustment, project, statistics, export,
                            # notification services + IdGenerator
  shared/
    providers/              # Riverpod providers (core, project, ticker, settings,
                            # statistics, history)
    widgets/                # DurationDisplay, StatusChip, EmptyState, EventTile…
  features/
    projects/   statistics/   history/   settings/   # feature-first UI
test/
  unit/  db/  widget/  integration/  helpers/
```

---

## The timer data model

The authoritative state lives in two tables:

- `timer_states` — one row per project: `status` (`stopped|running|paused`) and a nullable `runningStartedAtUtc`.
- `time_entries` — immutable, signed `signedDurationSeconds` rows (`timerSegment`, `manualAddition`, `manualRemoval`, `resetAdjustment`, `initialTime`, `importedAdjustment`).

A project's **stored total** is `SUM(signedDurationSeconds)`. When running, the **live total** is:

```
liveTotal = storedTotal + (nowUtc - runningStartedAtUtc)
```

The UI ticker (`tickerProvider`) only refreshes the *display* once per second, and only while at least one timer runs. It is never the source of truth, so closing the app, killing the process, or rebooting the device does not lose time — on reopen the elapsed time is recomputed from the persisted timestamp. All timestamps are stored in **UTC** and displayed in the device's local timezone. Sessions that cross local midnight are split per-day for daily charts (`TimeEntrySplitter`).

All state transitions (start/pause/resume/stop, manual adjustments, reset, delete, restore) run inside a single Drift transaction.

---

## Database schema (v1)

- **projects** — id (uuid PK), name, description, clientOrCategory, notes, colorValue, hourlyRateMinorUnits, currencyCode, deadlineUtc, createdAtUtc, updatedAtUtc, lastActivityAtUtc, archivedAtUtc, isArchived, deletedAtUtc.
- **timer_states** — projectId (PK/FK), status, runningStartedAtUtc, updatedAtUtc.
- **time_entries** — id (PK), projectId (FK), entryType, signedDurationSeconds, startedAtUtc, endedAtUtc, effectiveAtUtc, note, createdAtUtc, updatedAtUtc, metadataJson.
- **activity_events** — id (PK), projectId (nullable FK), eventType, occurredAtUtc, durationSeconds, note, metadataJson.
- **settings_entries** — key (PK), value.

Indexes cover `projectId`, `effectiveAtUtc`, `startedAtUtc`, `entryType`, `eventType`, `occurredAtUtc`, archived status, and last-activity. Foreign keys are enforced (`PRAGMA foreign_keys = ON`). DateTimes are stored as ISO-8601 UTC text for portable, ordered range queries.

---

## Getting started

### Prerequisites
- A current stable Flutter SDK (the project targets `flutter >= 3.22` / Dart `>= 3.4`).
- Android Studio with an Android SDK + an emulator or device.

### 1. Generate the Android platform shell
This repository ships `lib/`, tests, `pubspec.yaml`, and the key Android config files, but **not** the Gradle wrapper binary. From the project root, let Flutter fill in any missing platform scaffolding (it will not overwrite existing files):

```bash
flutter create . --org com.projecttime --project-name project_time --platforms=android
```

### 2. Install dependencies
```bash
flutter pub get
# optional but recommended (moves pins to current versions):
flutter pub upgrade --major-versions
```

### 3. Generate Drift code (required)
The Drift database relies on generated `*.g.dart` files (git-ignored). Generate them before building or testing:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run
```bash
flutter run
```

---

## Quality commands

```bash
dart format .
flutter analyze
flutter test
```

> `flutter test` requires the Drift codegen step above. The service/database/integration tests use an in-memory (and one file-backed) SQLite database via `sqlite3_flutter_libs`; on a desktop test host they rely on a system `sqlite3` library being available.

---

## Rebranding (app name & application ID)

Three places, all designed to be easy to change:

1. `lib/core/constants/app_constants.dart` → `AppConstants.appName`.
2. `android/app/build.gradle.kts` → `namespace` and `defaultConfig.applicationId`.
3. `android/app/src/main/AndroidManifest.xml` → `android:label`.

(Rename the Kotlin package folder under `android/app/src/main/kotlin/...` and the `package` line in `MainActivity.kt` to match a new application ID.)

---

## Privacy

All data is stored locally on the device in a SQLite database. The app requests **no internet permission**; the only optional permission is `POST_NOTIFICATIONS` for the ongoing running-timer notification, and the app is fully functional if it is denied. Backups are plain JSON that you export and store yourself. Imported files are validated and never executed, and CSV fields beginning with `= + - @` are neutralized against spreadsheet formula injection.

---

## Testing notes

- `test/unit` — duration formatting/parsing, date ranges, session splitting (timezone-independent), CSV escaping, and all services (timer, adjustment, project, statistics, export) using an injected `FakeClock` and deterministic IDs — **no real waiting**.
- `test/db` — foreign keys, cascade delete, reactive queries, clear-all.
- `test/widget` — duration display, status chip, and the Projects screen empty/populated states.
- `test/integration/end_to_end_test.dart` — the full two-project flow plus a file-backed "restart" that proves a running timer survives reopening.

---

## Known limitations

- Platform folders for the Gradle wrapper are generated by `flutter create .` (step 1) rather than committed.
- Generated Drift files are produced by `build_runner` (step 3) and are intentionally git-ignored.
