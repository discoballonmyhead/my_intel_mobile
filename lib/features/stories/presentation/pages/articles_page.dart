import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/signal_timeline.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/story.dart';
import '../providers/story_provider.dart';
import '../widgets/signal_story_row.dart';

/// Intel stories in the selected window as a "Signal" timeline: newest first,
/// grouped by day under sticky date chips, with a LIVE ticker of the regions
/// of recent breaking stories.
class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StoryProvider>();
      if (provider.status == StoryStatus.initial) provider.load();
    });
  }

  /// Regions of the latest breaking stories (then any story) for the ticker.
  static List<(String, String)> _tickerEntries(List<Story> newestFirst) {
    final seen = <String>{};
    final out = <(String, String)>[];
    final ordered = [
      ...newestFirst.where((s) => s.isBreaking),
      ...newestFirst.where((s) => !s.isBreaking),
    ];
    for (final s in ordered) {
      final region = s.region?.trim() ?? '';
      if (region.isEmpty || !seen.add(region.toLowerCase())) continue;
      out.add((region.toUpperCase(), SignalRow.ago(s.activityAt)));
      if (out.length == 6) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();
    final stories = [...provider.stories]
      ..sort((a, b) => b.activityAt.compareTo(a.activityAt));
    final ticker = _tickerEntries(stories);

    return Scaffold(
      appBar: AppBar(
        title: const Text('INTEL'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(84 + (ticker.isEmpty ? 0 : 30)),
          child: Column(
            children: [
              _WindowSelector(
                selected: provider.window,
                onChanged: provider.setWindow,
              ),
              _TagFilter(selected: provider.tag, onChanged: provider.setTag),
              if (ticker.isNotEmpty) LiveTicker(entries: ticker),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: switch (provider.status) {
          StoryStatus.initial || StoryStatus.loading =>
            const AppLoader(label: 'Ranking stories'),
          StoryStatus.error => AppErrorView(
              failure: provider.failure ?? const UnexpectedFailure(),
              onRetry: provider.load,
            ),
          StoryStatus.ready when provider.isEmpty => const AppEmptyView(
              message: 'No stories in this window',
              icon: Icons.newspaper_outlined,
            ),
          StoryStatus.ready => ContentColumn(
              padded: false,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  for (final day in SignalDay.group<Story>(
                      stories, (s) => s.activityAt))
                    SliverMainAxisGroup(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: SignalDayHeader(day.label),
                        ),
                        SliverList.builder(
                          itemCount: day.items.length,
                          itemBuilder: (context, index) {
                            final story = day.items[index];
                            return SignalStoryRow(
                              key: ValueKey(story.id),
                              story: story,
                              onTap: () =>
                                  context.push(AppRoutes.storyFor(story.id)),
                            );
                          },
                        ),
                      ],
                    ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxxl)),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({required this.selected, required this.onChanged});

  final TimeWindow selected;
  final ValueChanged<TimeWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: TimeWindow.values
            .map((w) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Center(
                    child: TagChip(
                      label: w.label,
                      selected: w == selected,
                      onTap: () => onChanged(w),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: AppConstants.mapFilters
            .map((tag) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Center(
                    child: TagChip(
                      label: tag,
                      selected: tag == selected,
                      onTap: () => onChanged(tag),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
