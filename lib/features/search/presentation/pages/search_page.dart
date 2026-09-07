import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../../stories/presentation/widgets/story_card.dart';
import '../providers/search_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();
    final palette = context.palette;
    final results = provider.results;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: provider.onQueryChanged,
          onSubmitted: (_) => provider.run(),
          decoration: InputDecoration(
            hintText: 'Search stories, posts, people, #tags',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: provider.searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          provider.onQueryChanged('');
                        },
                      ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                ...TimeWindow.values.map((w) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Center(
                        child: TagChip(
                          label: w.label,
                          selected: provider.window == w,
                          onTap: () => provider.setWindow(w),
                        ),
                      ),
                    )),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  color: palette.border,
                ),
                ...AppConstants.storyTags.map((t) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Center(
                        child: TagChip(
                          label: t,
                          selected: provider.tag == t,
                          onTap: () => provider.setTag(t),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
      body: !provider.hasQuery
          ? const AppEmptyView(
              message: 'Type at least two characters',
              icon: Icons.search_rounded,
            )
          : provider.failure != null
              ? AppErrorView(failure: provider.failure!, onRetry: provider.run)
              : results.isEmpty && !provider.searching
                  ? const AppEmptyView(message: 'No matches')
                  : ContentColumn(
                      padded: false,
                      child: ListView(
                        children: [
                          if (results.profiles.isNotEmpty) ...[
                            _SectionHeader(
                              label: 'PEOPLE',
                              count: results.profiles.length,
                            ),
                            ...results.profiles.map(
                              (p) => ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: palette.surface2,
                                  child: Text(
                                    p.username.characters.first.toUpperCase(),
                                    style: AppTypography.mono(
                                      size: 12,
                                      color: palette.accent,
                                    ),
                                  ),
                                ),
                                title: Text(p.username),
                                subtitle: p.isAnalyst
                                    ? Text(
                                        'CRED ${p.score}',
                                        style: AppTypography.mono(
                                          size: 9,
                                          color: palette.muted,
                                        ),
                                      )
                                    : null,
                                trailing: RoleBadge(role: p.role, compact: true),
                                onTap: () => context
                                    .push(AppRoutes.channelFor(p.username)),
                              ),
                            ),
                          ],
                          if (results.stories.isNotEmpty) ...[
                            _SectionHeader(
                              label: 'STORIES',
                              count: results.stories.length,
                            ),
                            ...results.stories.map(
                              (s) => StoryCard(
                                story: s,
                                onTap: () =>
                                    context.push(AppRoutes.storyFor(s.id)),
                              ),
                            ),
                          ],
                          if (results.posts.isNotEmpty) ...[
                            _SectionHeader(
                              label: 'POSTS',
                              count: results.posts.length,
                            ),
                            ...results.posts.map(
                              (p) => ListTile(
                                title: Text(
                                  p.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '@${p.author?.username ?? 'unknown'}',
                                  style: AppTypography.mono(
                                    size: 9,
                                    color: palette.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      color: palette.surface2,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        '$label · $count',
        style: AppTypography.mono(
          size: 9,
          color: palette.muted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
