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
import '../../../../core/widgets/tag_chip.dart';
import '../providers/story_provider.dart';
import '../widgets/story_card.dart';

/// Trending intelligence stories, ranked by the time-decay scorer.
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('INTEL'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Column(
            children: [
              _WindowSelector(
                selected: provider.window,
                onChanged: provider.setWindow,
              ),
              _TagFilter(selected: provider.tag, onChanged: provider.setTag),
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
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                itemCount: provider.ranked.length,
                itemBuilder: (context, index) {
                  final story = provider.ranked[index].story;
                  return StoryCard(
                    story: story,
                    onTap: () => context.push(AppRoutes.storyFor(story.id)),
                  );
                },
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
