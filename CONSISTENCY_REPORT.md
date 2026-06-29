# Project Time — Consistency Pass Report

A full cross-codebase consistency pass was run over all 92 files. The app was **not redesigned** — only completed, fixed, and verified.

## 1. Audit results (12 focus areas)

| # | Area | Result |
|---|------|--------|
| 1 | Missing imports | **Pass** — every used package/symbol is imported (relative + `package:` resolved programmatically). |
| 2 | Wrong relative paths | **Pass** — all relative imports and `part`/`part of` URIs resolve to real files. |
| 3 | Drift generated-file assumptions | **Pass** — `part 'app_database.g.dart'`, the `_$AppDatabase` superclass, the five `_$…DaoMixin`s, row classes (`Project`, `TimerState`, `TimeEntry`, `ActivityEvent`, `SettingsEntry`) and `*Companion`s all follow drift's naming. They are produced by `build_runner` (see §3). |
| 4 | Provider name mismatches | **Pass** — 39 providers defined; every referenced provider exists **and** its defining file is imported by each consumer. |
| 5 | Router imports | **Pass** — all six screen classes referenced in `app_router.dart` exist with matching names/paths. |
| 6 | Enum/string converter consistency | **Pass** — `TimerStatus`/`EntryType`/`EventType` stored via `.name`, read via `.values.byName`; query filters compare against `.name`. |
| 7 | Database schema consistency | **Pass** — table/column names match every companion and DAO; indexes + FKs declared; `PRAGMA foreign_keys = ON` in `beforeOpen`. |
| 8 | Timer transaction correctness | **Pass** — start/pause/resume/stop/pauseAll/reset/delete each run in a single `transaction`; segments guard against zero/negative intervals; live time is computed, never accumulated. |
| 9 | Statistics calculation edge cases | **Pass** — net floored at zero; empty donut returns `[]`; divide-by-zero guarded (active-day average, chart maxY); sessions split across local-day/bucket boundaries; reset adjustments excluded from tracked charts. |
| 10 | Android manifest / notifications | **Pass** — `POST_NOTIFICATIONS` only (no `INTERNET` in main), `flutterEmbedding=2`, `flutter_local_notifications` receivers, channel IDs match `AppConstants`, `namespace`/`applicationId`/Kotlin package all `com.projecttime.app`, core-library desugaring enabled. |
| 11 | pubspec completeness | **Pass** — every imported package is declared; removed two unused deps (`collection`, `permission_handler`). |
| 12 | README run instructions | **Pass** — `flutter create .` → `pub get`/`upgrade` → `build_runner` → run/analyze/test, with rebranding + privacy notes. |

## 2. Issues found and fixed

1. **NUL-byte corruption** (editor artifact) was found and stripped from 4 files: `lib/app.dart`, `lib/domain/services/notification_service.dart`, `lib/features/statistics/presentation/widgets/stat_section.dart`, `lib/features/statistics/presentation/widgets/summary_metrics.dart` (plus `pubspec.yaml`, `analysis_options.yaml`, `README.md` after later edits). All content was intact — only NUL bytes on blank lines were removed. Final sweep: **0 NUL bytes** remain anywhere.
2. **Unused dependencies removed**: `collection` and `permission_handler` (notification permission is handled by `flutter_local_notifications`). README package table updated to match.
3. **Obsolete analyzer override removed** (`missing_return`) and `strict-raw-types` relaxed to avoid false-positive analyzer errors; `strict-casts` kept.
4. **`AndroidNotificationCategory.stopwatch`** removed from the notification (version-fragile field) — no functional impact.

> Note: brace/paren "imbalances" reported by a naive scan were all bracket-notation inside doc comments/strings (e.g. `[start, end)`), not code.

## 3. Files that MUST be generated locally (not in this repo)

**By Drift (`build_runner`) — required to compile:**
- `lib/data/database/app_database.g.dart`

**By `flutter create .` — Android shell + tooling:**
- `android/gradle/wrapper/gradle-wrapper.properties` and `gradle-wrapper.jar`
- `android/gradlew`, `android/gradlew.bat`
- `android/local.properties` (your SDK paths — never commit)
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (launcher icons)
- `.metadata` and any other missing platform glue

(These are intentionally git-ignored / not hand-written; `*.g.dart` is in `.gitignore`.)

## 4. Exact commands to run locally

```bash
# from the project root: "Project Time"

# 1) Generate the Android platform shell + Gradle wrapper (won't overwrite lib/)
flutter create . --org com.projecttime --project-name project_time --platforms=android

# 2) Dependencies (the second line moves the conservative pins to current versions)
flutter pub get
flutter pub upgrade --major-versions

# 3) REQUIRED: generate Drift code (creates app_database.g.dart)
dart run build_runner build --delete-conflicting-outputs

# 4) Verify
dart format .
flutter analyze
flutter test

# 5) Run on a device/emulator
flutter run
```

## 5. Expected errors and how to fix them

| Symptom | Cause | Fix |
|---|---|---|
| `Target of URI hasn't been generated: 'app_database.g.dart'` / `_$AppDatabase isn't defined` / `_$ProjectsDaoMixin` undefined | Drift code not generated yet | Run step 3 (`dart run build_runner build --delete-conflicting-outputs`). |
| Analyzer shows ~thousands of errors before codegen | Same — generated part missing | Same as above; analyze **after** build_runner. |
| `build_runner` fails with version conflicts | `drift`/`drift_dev` majors drifted apart after upgrade | Keep `drift` and `drift_dev` on the **same** major; re-run `flutter pub get` then build_runner. |
| `flutter.sdk not set in local.properties` (Gradle) | `local.properties` not created | Run `flutter create .` (step 1) or `flutter run` once; it writes `local.properties`. |
| Gradle wrapper / `gradlew` missing | Wrapper not committed | Step 1 generates it. |
| `fl_chart` API errors after `pub upgrade` (e.g. `SideTitles`, `getTitlesWidget`) | A **major** `fl_chart` bump (e.g. 1.x) changed the API | Either pin `fl_chart` to the `^0.69` line, or adjust the four chart widgets in `lib/features/statistics/presentation/widgets/` to the new API. This is the single most likely upgrade break. |
| `flutter test` host error: `Failed to load dynamic library …sqlite3…` | No system SQLite on the test host | Install it (`apt-get install libsqlite3-0`, `brew install sqlite3`, or add `sqlite3` libs); on-device tests already bundle it via `sqlite3_flutter_libs`. |
| Deprecation **info** for `RadioListTile` `groupValue`/`onChanged` | Newer Flutter prefers `RadioGroup` | Informational only — not an error; safe to leave. |
| `withValues`/`toARGB32` undefined | Flutter older than 3.27 | You're on current stable (fine); if you must use an older SDK, replace with `withOpacity(...)` and `.value`. |
| Desugaring error mentioning `desugar_jdk_libs` version | AGP wants a newer desugar lib | Bump the version in `android/app/build.gradle.kts` (`coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:<newer>")`). |

## 6. Final QA checklist

Run top-to-bottom; each maps to an acceptance criterion.

- [ ] `flutter create .` completes; `android/` wrapper + icons present.
- [ ] `flutter pub get` resolves with no version conflicts.
- [ ] `dart run build_runner build --delete-conflicting-outputs` writes `app_database.g.dart` with no errors.
- [ ] `flutter analyze` → **no errors** (deprecation infos acceptable).
- [ ] `flutter test` → all unit/db/widget/integration tests pass.
- [ ] App launches to the Projects empty state.
- [ ] Create a project; it appears in the list.
- [ ] Start a timer; the display ticks once per second.
- [ ] Start a **second** project's timer; both run independently.
- [ ] Background/kill the app; reopen → running total reflects elapsed wall-clock time.
- [ ] Pause / resume / stop behave per state; totals accumulate correctly.
- [ ] Add time and remove time; removal beyond total is blocked.
- [ ] Reset total → shows 0 but history retains prior entries.
- [ ] History tab lists sessions + corrections, filterable, grouped by day.
- [ ] Statistics tab: ranges switch; bars/line/donut/heatmap render; empty states show with no data.
- [ ] Session crossing local midnight is split across two days in daily charts.
- [ ] Archive / restore / delete (with double-confirm) behave correctly.
- [ ] Export CSV and JSON backup share successfully; restore (replace + merge) works; malformed file rejected.
- [ ] Light / dark / system themes apply.
- [ ] Rebrand check: changing `applicationId` + `AppConstants.appName` + manifest label renames cleanly.
