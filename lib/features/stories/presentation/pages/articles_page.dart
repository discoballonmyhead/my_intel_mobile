import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/mint_logo.dart';
import '../../domain/entities/story.dart';
import '../providers/story_provider.dart';
import '../widgets/intel_filter_sheet.dart';
import '../widgets/intel_message.dart';
import '../widgets/intel_story_card.dart';

/// Intel: stories as soft cards, newest first, grouped under quiet day labels.
/// Search bar and filter button on top, then All / Following tabs.
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

  Future<void> _openFilters(StoryProvider provider) async {
    final picked = await IntelFilterSheet.show(context, provider);
    if (picked != null) await provider.setFilters(picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StoryProvider>();
    final stories = [...provider.visibleStories]
      ..sort((a, b) => b.activityAt.compareTo(a.activityAt));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: 52,
              child: Center(child: MintLogo(height: 30, animate: false)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child:
                        _SearchBar(onTap: () => context.push(AppRoutes.search)),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    active: provider.filters.isActive,
                    onTap: () => _openFilters(provider),
                  ),
                ],
              ),
            ),
            _Tabs(
                following: provider.following,
                onChanged: provider.setFollowing),
            if (provider.filters.isActive && !provider.following)
              _ActiveFilters(
                filters: provider.filters,
                onChanged: provider.setFilters,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: ContentColumn(
                  padded: false,
                  child: _body(context, provider, stories),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, StoryProvider provider, List<Story> stories) {
    if (provider.following) {
      return const IntelMessage(
        icon: Icons.people_outline_rounded,
        title: 'Nothing from people you follow yet',
        body: 'Stories show up here when people you follow report on them.',
      );
    }
    switch (provider.status) {
      case StoryStatus.initial || StoryStatus.loading:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 14),
          children: List.generate(4, (_) => const IntelStoryCardSkeleton()),
        );
      case StoryStatus.error:
        return IntelMessage(
          icon: Icons.wifi_off_rounded,
          title: 'Can’t load stories',
          body: 'Check your connection and try again.',
          action: 'Try again',
          outlined: true,
          onAction: provider.load,
        );
      case StoryStatus.ready when stories.isEmpty:
        if (provider.filters.isActive) {
          return IntelMessage(
            title: 'No stories match your filters',
            body: 'Try fewer filters or a longer time window.',
            action: 'Clear filters',
            onAction: () => provider.setFilters(IntelFilters.none),
          );
        }
        return const IntelMessage(
          title: 'No stories yet',
          body: 'Stories appear here as reports come in.',
        );
      case StoryStatus.ready:
        final groups = _groupByDay(stories);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            for (final (label, items) in groups) ...[
              _DayLabel(label),
              for (final story in items)
                IntelStoryCard(
                  key: ValueKey(story.id),
                  story: story,
                  onTap: () => context.push(AppRoutes.storyFor(story.id)),
                ),
            ],
          ],
        );
    }
  }

  /// Today, Yesterday, This week, Earlier — in that order, empty groups dropped.
  static List<(String, List<Story>)> _groupByDay(List<Story> newestFirst) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String label(DateTime t) {
      final local = t.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      if (diff <= 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return 'This week';
      return 'Earlier';
    }

    final groups = <String, List<Story>>{};
    for (final s in newestFirst) {
      groups.putIfAbsent(label(s.activityAt), () => []).add(s);
    }
    return [
      for (final key in ['Today', 'Yesterday', 'This week', 'Earlier'])
        if (groups[key] case final items?) (key, items),
    ];
  }
}

/// Looks like a text field; opens the Search page.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Search',
      excludeSemantics: true,
      child: Material(
        color: palette.surface2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search_rounded, size: 22, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Search stories, places, topics',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: palette.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round filter button; a red dot shows when any filter is on.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: active ? 'Filters, on' : 'Filters',
      excludeSemantics: true,
      child: Material(
        color: palette.surface2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.tune_rounded,
                    size: 22, color: Theme.of(context).colorScheme.onSurface),
                if (active)
                  Positioned(
                    top: 7,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: palette.accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// All / Following, each half the width with an underline on the selected one.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.following, required this.onChanged});
  final bool following;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget tab(String label, bool value) {
      final on = following == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            onTap: on ? null : () => onChanged(value),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        color: on ? onSurface : palette.muted)),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: on ? label.length * 8.0 + 16 : 0,
                  decoration: BoxDecoration(
                      color: onSurface, borderRadius: BorderRadius.circular(1)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(children: [tab('All', false), tab('Following', true)]),
    );
  }
}

/// Removable chips for each filter that is on, plus "Clear".
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters, required this.onChanged});
  final IntelFilters filters;
  final ValueChanged<IntelFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chips = <(String, IntelFilters)>[
      for (final t in filters.topics)
        (
          intelTopicLabel(t),
          filters.copyWith(topics: {...filters.topics}..remove(t))
        ),
      if (filters.window != TimeWindow.all)
        (
          intelWindowLabel(filters.window),
          filters.copyWith(window: TimeWindow.all)
        ),
      if (filters.minConfidence != MinConfidence.any)
        (
          filters.minConfidence.label,
          filters.copyWith(minConfidence: MinConfidence.any)
        ),
      if (filters.breakingOnly)
        ('Breaking only', filters.copyWith(breakingOnly: false)),
    ];

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          for (final (label, without) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                label: 'Remove $label',
                excludeSemantics: true,
                child: Material(
                  color: palette.surface2,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(without),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Row(
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded,
                              size: 16, color: palette.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Center(
            child: GestureDetector(
              onTap: () => onChanged(IntelFilters.none),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Clear',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.palette.muted)),
    );
  }
}
