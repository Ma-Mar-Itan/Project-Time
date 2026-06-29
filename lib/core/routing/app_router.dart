import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/history/presentation/history_screen.dart';
import '../../features/projects/presentation/screens/add_edit_project_screen.dart';
import '../../features/projects/presentation/screens/project_detail_screen.dart';
import '../../features/projects/presentation/screens/projects_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';
import '../../shared/widgets/home_shell.dart';

/// Route path constants (kept together so links never drift from definitions).
class Routes {
  const Routes._();
  static const projects = '/projects';
  static const statistics = '/statistics';
  static const history = '/history';
  static const settings = '/settings';
  static const newProject = '/projects/new';

  static String projectDetail(String id) => '/projects/$id';
  static String editProject(String id) => '/projects/$id/edit';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.projects,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.projects,
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.statistics,
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.newProject,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AddEditProjectScreen(),
      ),
      GoRoute(
        path: '/projects/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            AddEditProjectScreen(projectId: state.pathParameters['id']),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
}
