import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/enums.dart';
import 'shared/providers/core_providers.dart';
import 'shared/providers/project_providers.dart';
import 'shared/providers/settings_provider.dart';

/// Root application widget. Wires the router, theming, and the notification
/// sync side-effect (which mirrors running timers into an ongoing notification).
class ProjectTimeApp extends ConsumerStatefulWidget {
  const ProjectTimeApp({super.key});

  @override
  ConsumerState<ProjectTimeApp> createState() => _ProjectTimeAppState();
}

class _ProjectTimeAppState extends ConsumerState<ProjectTimeApp> {
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // Keep the ongoing notification in sync with the set of running timers,
    // updating only when that set changes (never every second).
    ref.listen(
      runningTimerStatesProvider.select(
        (async) => async.valueOrNull?.length ?? 0,
      ),
      (previous, next) {
        final service = ref.read(notificationServiceProvider);
        if (!settings.runningNotificationEnabled) {
          service.clear();
          return;
        }
        final names = ref
                .read(projectViewsProvider)
                .valueOrNull
                ?.where((v) => v.status == TimerStatus.running)
                .map((v) => v.name)
                .toList() ??
            const <String>[];
        service.updateRunning(
          runningCount: next,
          sampleProjectNames: names,
        );
      },
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: _router,
    );
  }
}
