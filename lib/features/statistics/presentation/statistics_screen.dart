import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/statistics.dart';
import '../../../shared/providers/statistics_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/longest_sessions_list.dart';
import 'widgets/over_time_chart.dart';
import 'widgets/project_bars.dart';
import 'widgets/project_donut.dart';
import 'widgets/range_selector.dart';
import 'widgets/sources_breakdown.dart';
import 'widgets/stat_section.dart';
import 'widgets/summary_metrics.dart';

/// The Statistics tab: a range selector and a scrollable set of charts.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(statisticsResultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Column(
        children: [
          const RangeSelector(),
          Expanded(
            child: resultAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Something went wrong: $error'),
                ),
              ),
              data: (result) => _StatisticsBody(result: result),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({required this.result});

  final StatisticsResult result;

  @override
  Widget build(BuildContext context) {
    if (result.isEmpty) {
      return const EmptyState(
        icon: Icons.insights,
        title: 'No recorded time yet',
        message:
            'Statistics will appear after you record your first session.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        StatSection(
          title: 'Summary',
          child: SummaryMetrics(summary: result.summary),
        ),
        const SectionGap(),
        StatSection(
          title: 'Time by project',
          child: ProjectBars(stats: result.byProject),
        ),
        const SectionGap(),
        StatSection(
          title: 'Time over time',
          child: OverTimeChart(buckets: result.overTime),
        ),
        const SectionGap(),
        StatSection(
          title: 'Project share',
          child: ProjectDonut(slices: result.donut),
        ),
        const SectionGap(),
        StatSection(
          title: 'Timer vs manual',
          child: SourcesBreakdown(sources: result.sources),
        ),
        const SectionGap(),
        StatSection(
          title: 'Activity calendar',
          child: ActivityHeatmap(days: result.heatmap),
        ),
        const SectionGap(),
        StatSection(
          title: 'Longest sessions',
          child: LongestSessionsList(sessions: result.longestSessions),
        ),
      ],
    );
  }
}
