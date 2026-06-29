import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/project_view.dart';
import 'core_providers.dart';

enum ProjectFilter { all, running, paused, stopped, archived }

extension ProjectFilterLabel on ProjectFilter {
  String get label => switch (this) {
        ProjectFilter.all => 'All',
        ProjectFilter.running => 'Running',
        ProjectFilter.paused => 'Paused',
        ProjectFilter.stopped => 'Stopped',
        ProjectFilter.archived => 'Archived',
      };
}

final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(databaseProvider).projectsDao.watchActive();
});

final archivedProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(databaseProvider).projectsDao.watchArchived();
});

final allProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(databaseProvider).projectsDao.watchAllIncludingArchived();
});

final allTimerStatesProvider = StreamProvider<List<TimerState>>((ref) {
  return ref.watch(databaseProvider).timerDao.watchAll();
});

final runningTimerStatesProvider = StreamProvider<List<TimerState>>((ref) {
  return ref.watch(databaseProvider).timerDao.watchRunning();
});

final runningCountProvider = Provider<int>((ref) {
  return ref.watch(runningTimerStatesProvider).valueOrNull?.length ?? 0;
});

final projectTotalsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(databaseProvider).timeEntriesDao.watchProjectTotals();
});

final projectByIdProvider =
    StreamProvider.family<Project?, String>((ref, id) {
  return ref.watch(databaseProvider).projectsDao.watchById(id);
});

final timerStateByIdProvider =
    StreamProvider.family<TimerState?, String>((ref, id) {
  return ref.watch(databaseProvider).timerDao.watchByProject(id);
});

/// Builds [ProjectView]s for the active project list, sorted by status group
/// (running, paused, stopped) then by most recent activity.
final projectViewsProvider = Provider<AsyncValue<List<ProjectView>>>((ref) {
  final projects = ref.watch(activeProjectsProvider);
  final timers = ref.watch(allTimerStatesProvider);
  final totals = ref.watch(projectTotalsProvider);

  return _combine3(projects, timers, totals, (projectList, timerList, totalMap) {
    final statusById = {for (final t in timerList) t.projectId: t};
    final views = projectList.map((p) {
      final state = statusById[p.id];
      return ProjectView(
        project: p,
        status: state?.status ?? TimerStatus.stopped,
        runningStartedAtUtc: state?.runningStartedAtUtc,
        storedSeconds: totalMap[p.id] ?? 0,
      );
    }).toList();
    views.sort(_compareViews);
    return views;
  });
});

final archivedProjectViewsProvider =
    Provider<AsyncValue<List<ProjectView>>>((ref) {
  final projects = ref.watch(archivedProjectsProvider);
  final timers = ref.watch(allTimerStatesProvider);
  final totals = ref.watch(projectTotalsProvider);
  return _combine3(projects, timers, totals, (projectList, timerList, totalMap) {
    final statusById = {for (final t in timerList) t.projectId: t};
    return projectList
        .map((p) => ProjectView(
              project: p,
              status: statusById[p.id]?.status ?? TimerStatus.stopped,
              runningStartedAtUtc: statusById[p.id]?.runningStartedAtUtc,
              storedSeconds: totalMap[p.id] ?? 0,
            ))
        .toList();
  });
});

final singleProjectViewProvider =
    Provider.family<AsyncValue<ProjectView?>, String>((ref, id) {
  final project = ref.watch(projectByIdProvider(id));
  final timer = ref.watch(timerStateByIdProvider(id));
  final totals = ref.watch(projectTotalsProvider);
  return _combine3(project, timer, totals, (p, t, totalMap) {
    if (p == null) return null;
    return ProjectView(
      project: p,
      status: t?.status ?? TimerStatus.stopped,
      runningStartedAtUtc: t?.runningStartedAtUtc,
      storedSeconds: totalMap[p.id] ?? 0,
    );
  });
});

// --- list filtering ---

final projectFilterProvider =
    StateProvider<ProjectFilter>((ref) => ProjectFilter.all);

final projectSearchProvider = StateProvider<String>((ref) => '');

/// The filtered + searched project list shown on the Projects tab.
final filteredProjectViewsProvider =
    Provider<AsyncValue<List<ProjectView>>>((ref) {
  final filter = ref.watch(projectFilterProvider);
  final query = ref.watch(projectSearchProvider).trim().toLowerCase();

  final source = filter == ProjectFilter.archived
      ? ref.watch(archivedProjectViewsProvider)
      : ref.watch(projectViewsProvider);

  return source.whenData((views) {
    Iterable<ProjectView> result = views;
    switch (filter) {
      case ProjectFilter.running:
        result = result.where((v) => v.isRunning);
        break;
      case ProjectFilter.paused:
        result = result.where((v) => v.isPaused);
        break;
      case ProjectFilter.stopped:
        result = result.where((v) => v.isStopped);
        break;
      case ProjectFilter.all:
      case ProjectFilter.archived:
        break;
    }
    if (query.isNotEmpty) {
      result = result.where((v) {
        final name = v.project.name.toLowerCase();
        final notes = (v.project.notes ?? '').toLowerCase();
        final client = (v.project.clientOrCategory ?? '').toLowerCase();
        return name.contains(query) ||
            notes.contains(query) ||
            client.contains(query);
      });
    }
    return result.toList();
  });
});

int _statusRank(ProjectView v) {
  if (v.isRunning) return 0;
  if (v.isPaused) return 1;
  return 2;
}

int _compareViews(ProjectView a, ProjectView b) {
  final rank = _statusRank(a).compareTo(_statusRank(b));
  if (rank != 0) return rank;
  final aDate = a.project.lastActivityAtUtc ?? a.project.createdAtUtc;
  final bDate = b.project.lastActivityAtUtc ?? b.project.createdAtUtc;
  return bDate.compareTo(aDate);
}

/// Combines three [AsyncValue]s, surfacing loading/error states.
AsyncValue<R> _combine3<A, B, C, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  R Function(A, B, C) build,
) {
  if (a.isLoading || b.isLoading || c.isLoading) {
    if (a.hasValue && b.hasValue && c.hasValue) {
      return AsyncData(build(a.value as A, b.value as B, c.value as C));
    }
    return const AsyncLoading();
  }
  if (a.hasError) return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  if (b.hasError) return AsyncError(b.error!, b.stackTrace ?? StackTrace.current);
  if (c.hasError) return AsyncError(c.error!, c.stackTrace ?? StackTrace.current);
  return AsyncData(build(a.value as A, b.value as B, c.value as C));
}
