import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../domain/models/project_view.dart';
import '../../../../shared/providers/project_providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../project_actions.dart';
import '../widgets/project_card.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() {
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(projectSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(projectFilterProvider);
    final viewsAsync = ref.watch(filteredProjectViewsProvider);
    final allViews = ref.watch(projectViewsProvider).valueOrNull ?? const [];
    final runningCount = allViews.where((v) => v.isRunning).length;
    final activeCount = allViews.length;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search projects',
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    ref.read(projectSearchProvider.notifier).state = value,
              )
            : _TitleWithSummary(
                running: runningCount, active: activeCount),
        actions: [
          if (_searching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearch,
              tooltip: 'Close search',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
              tooltip: 'Search',
            ),
            if (runningCount > 0)
              IconButton(
                icon: const Icon(Icons.pause_circle_outline),
                tooltip: 'Pause all running timers',
                onPressed: () =>
                    ProjectActions.pauseAll(context, ref, runningCount),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newProject),
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
      body: Column(
        children: [
          _FilterBar(selected: filter),
          Expanded(
            child: viewsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Something went wrong: $e')),
              data: (views) => _ProjectList(
                views: views,
                filter: filter,
                searching:
                    ref.watch(projectSearchProvider).trim().isNotEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleWithSummary extends StatelessWidget {
  const _TitleWithSummary({required this.running, required this.active});
  final int running;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (running > 0) '$running running',
      '$active active project${active == 1 ? '' : 's'}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Projects'),
        Text(
          parts.join(' · '),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});
  final ProjectFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in ProjectFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: f == selected,
                onSelected: (_) =>
                    ref.read(projectFilterProvider.notifier).state = f,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.views,
    required this.filter,
    required this.searching,
  });

  final List<ProjectView> views;
  final ProjectFilter filter;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    if (views.isEmpty) {
      if (searching) {
        return const EmptyState(
          icon: Icons.search_off,
          title: 'No matches',
          message: 'No projects match your search.',
        );
      }
      if (filter == ProjectFilter.archived) {
        return const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No archived projects',
          message: 'Archived projects will appear here.',
        );
      }
      if (filter != ProjectFilter.all) {
        return EmptyState(
          icon: Icons.filter_list_off,
          title: 'No ${filter.label.toLowerCase()} projects',
          message: 'Try a different filter.',
        );
      }
      return const _NoProjectsState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: views.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => ProjectCard(view: views[index]),
    );
  }
}

class _NoProjectsState extends StatelessWidget {
  const _NoProjectsState();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.checklist,
      title: 'No projects yet',
      message: 'Create a project to begin tracking time.\n'
          'Tip: you can run several project timers at the same time.',
      action: FilledButton.icon(
        onPressed: () => context.push(Routes.newProject),
        icon: const Icon(Icons.add),
        label: const Text('Create project'),
      ),
    );
  }
}
