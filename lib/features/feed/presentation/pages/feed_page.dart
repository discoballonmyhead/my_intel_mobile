import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/mint_logo.dart';
import '../../../../core/responsive/responsive_provider.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../profile/presentation/providers/profile_cubit.dart';
import '../../../moderation/presentation/widgets/mod_actions.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../../comments/presentation/pages/post_detail_page.dart';
import '../../domain/entities/post.dart';
import '../providers/feed_provider.dart';
import '../widgets/composer_sheet.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/edit_post_sheet.dart';
import '../widgets/post_actions_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/post_edit_history_sheet.dart';
import '../widgets/quote_composer.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

enum _FeedFilter { all, following, news }

class _FeedPageState extends State<FeedPage> {
  final _scroll = ScrollController();
  _FeedFilter _filter = _FeedFilter.all;
  bool _headerVisible = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setHeader(bool visible) {
    if (_headerVisible != visible) setState(() => _headerVisible = visible);
  }

  /// Hide the header while reading down the feed, bring it back on any
  /// upward scroll or near the top.
  bool _onScroll(ScrollUpdateNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final dy = n.scrollDelta ?? 0;
    if (n.metrics.pixels <= 12) {
      _setHeader(true);
    } else if (dy > 6) {
      _setHeader(false);
    } else if (dy < -6) {
      _setHeader(true);
    }
    return false;
  }

  void _revealNew(FeedProvider provider) {
    provider.revealPending();
    _setHeader(true);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  List<FeedItem> _visible(FeedProvider provider) {
    return switch (_filter) {
      _FeedFilter.all => provider.items,
      _FeedFilter.following => provider.items.where((item) {
          final followed = provider.followedIds;
          if (followed.contains(item.post.authorId)) return true;
          return item is RepostedPost && followed.contains(item.reposter?.id);
        }).toList(),
      _FeedFilter.news =>
        provider.items.where((i) => i.post.postType == 'news').toList(),
    };
  }

  String _emptyMessage(FeedProvider provider) => switch (_filter) {
        _FeedFilter.all => 'Nothing here yet',
        _FeedFilter.following => provider.followedIds.isEmpty
            ? 'Follow people to see their posts here'
            : 'No posts from people you follow yet',
        _FeedFilter.news => 'No news yet',
      };

  @override
  void initState() {
    super.initState();
    // Deferred so the first frame paints before the network call starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FeedProvider>();
      if (provider.status == FeedStatus.initial) provider.load();
      provider.listenForNewPosts();
    });
  }

  Future<void> _openComposer() async {
    final params = await ComposerSheet.show(context);
    if (params == null || !mounted) return;

    final provider = context.read<FeedProvider>();
    final ok = await provider.createPost(params);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Posted.' : provider.failure?.message ?? 'Post failed.'),
      ),
    );
  }

  /// Copies the post's web link, the same link the web app's Share copies.
  Future<void> _sharePost(Post post) async {
    final url = '${Env.webAppUrl}/feed?highlight=${post.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  /// "Repost with a comment": write the comment, then repost with it.
  Future<void> _quote(Post post) async {
    final me = context.read<ProfileCubit>().state.profile;
    final comment = await QuoteComposer.show(context, post, username: me?.username);
    if (comment == null || !mounted) return;
    await context.read<FeedProvider>().toggleRepost(post, quote: comment, me: me);
  }

  Future<void> _openActions(Post post) async {
    final action = await PostActionsSheet.show(
      context,
      post: post,
      myUserId: context.read<AuthCubit>().state.user?.id,
      isStaff: context.read<AccessCubit>().state.isStaff,
    );
    if (action == null || !mounted) return;
    final provider = context.read<FeedProvider>();

    switch (action) {
      case PostAction.edit:
        {
          final body = await EditPostSheet.show(context, post);
          if (body == null || !mounted) return;
          final ok = await provider.editPost(post, body);
          if (!mounted) return;
          AppDialogs.snack(context,
              ok ? 'Post updated.' : provider.failure?.message ?? 'Edit failed.');
        }
      case PostAction.delete:
        {
          final confirmed = await AppDialogs.confirm(
            context,
            title: 'Delete post?',
            message: 'It disappears from every feed. This cannot be undone.',
            confirmLabel: 'DELETE',
            destructive: true,
          );
          if (!confirmed || !mounted) return;
          final ok = await provider.deletePost(post);
          if (!mounted) return;
          AppDialogs.snack(context,
              ok ? 'Post deleted.' : provider.failure?.message ?? 'Delete failed.');
        }
      case PostAction.history:
        await PostEditHistorySheet.show(context, post);
      case PostAction.report:
        await ReportSheet.show(
          context,
          targetType: ReportTargetType.post,
          targetId: '${post.id}',
        );
      case PostAction.modRemove:
        {
          final removed = await ModActions.removePost(context, post.id);
          if (removed && mounted) provider.removeLocally(post.id);
        }
      case PostAction.viewAuthor:
        {
          final username = post.author?.username;
          if (username != null) context.push(AppRoutes.channelFor(username));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedProvider>();
    final responsive = context.watch<ResponsiveProvider>();
    final items = _visible(provider);

    final Widget content = switch (provider.status) {
      FeedStatus.initial || FeedStatus.loading => const FeedSkeleton(),
      FeedStatus.error => AppErrorView(
          failure: provider.failure ?? const UnexpectedFailure(),
          onRetry: provider.load,
        ),
      FeedStatus.ready when items.isEmpty => ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            AppEmptyView(
              message: _emptyMessage(provider),
              icon: _filter == _FeedFilter.news
                  ? Icons.newspaper_rounded
                  : Icons.rss_feed_rounded,
            ),
          ],
        ),
      FeedStatus.ready => ContentColumn(
          padded: false,
          maxWidth: responsive.isExpanded ? 720 : 680,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final key = switch (item) {
                RepostedPost(:final repostId) => 'r$repostId',
                _ => 'p${item.post.id}',
              };
              return PostCard(
                key: ValueKey(key),
                item: item,
                highlight: provider.freshIds.contains(item.post.id),
                onLike: () => provider.toggleLike(item.post),
                onSave: () => provider.toggleSave(item.post),
                onRepost: () => provider.toggleRepost(item.post,
                    me: context.read<ProfileCubit>().state.profile),
                onQuote: () => unawaited(_quote(item.post)),
                myUserId: context.read<AuthCubit>().state.user?.id,
                onShare: () => unawaited(_sharePost(item.post)),
                onAuthorTap: (username) =>
                    unawaited(context.push(AppRoutes.channelFor(username))),
                onMore: () => _openActions(item.post),
              );
            },
          ),
        ),
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        // Unique per tab: all shell tabs stay mounted (indexedStack), so the
        // default tag would collide with other tabs' FABs on every push.
        heroTag: 'fab-feed-compose',
        onPressed: provider.posting ? null : _openComposer,
        child: provider.posting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CollapsingHeader(
              visible: _headerVisible,
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const MintLogo(height: 30, animate: false),
                        Positioned(
                          right: 6,
                          child: IconButton(
                            tooltip: 'Search',
                            icon: const Icon(Icons.search_rounded),
                            onPressed: () => context.push(AppRoutes.search),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FilterChips(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollUpdateNotification>(
                    onNotification: _onScroll,
                    child: RefreshIndicator(
                      onRefresh: provider.refresh,
                      child: content,
                    ),
                  ),
                  if (provider.pendingCount > 0)
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _NewPostsPill(
                          count: provider.pendingCount,
                          authors: provider.pendingAuthors,
                          onTap: () => _revealNew(provider),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          FeedStatus.ready => ContentColumn(
              padded: false,
              maxWidth: responsive.isExpanded ? 720 : 680,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
                itemCount: provider.items.length,
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return PostCard(
                    item: item,
                    onLike: () => provider.toggleLike(item.post),
                    onSave: () => provider.toggleSave(item.post),
                    onRepost: () => provider.toggleRepost(item.post),
                    onAuthorTap: (username) =>
                        context.push(AppRoutes.channelFor(username)),
                    onMore: () => _openActions(item.post),
                    onTap: () =>
                        context.push(AppRoutes.postFor(item.post.id)),
                    onComment: () => context.push(
                        AppRoutes.postFor(item.post.id),
                        extra: const PostDetailArgs(focusComposer: true)),
                  );
                },
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Theme.of(context).colorScheme.surface
                      : onSurface,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          chip(_FeedFilter.all, 'All'),
          const SizedBox(width: 8),
          chip(_FeedFilter.following, 'Following'),
          const SizedBox(width: 8),
          chip(_FeedFilter.news, 'News'),
        ],
      ),
    );
  }
}

/// "↑ N new posts" with up to two author initials.
class _NewPostsPill extends StatelessWidget {
  const _NewPostsPill({
    required this.count,
    required this.authors,
    required this.onTap,
  });

  final int count;
  final List<String> authors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -10 * (1 - t)), child: child),
      ),
      child: Material(
        color: palette.accent,
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: palette.accent.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(authors.isEmpty ? 14 : 6, 6, 14, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < authors.length; i++)
                  Transform.translate(
                    offset: Offset(-8.0 * i, 0),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.surface2,
                        border: Border.all(color: palette.accent, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        authors[i].characters.first.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: palette.accent),
                      ),
                    ),
                  ),
                SizedBox(width: authors.isEmpty ? 0 : 8.0 - 8.0 * (authors.length - 1)),
                Icon(Icons.arrow_upward_rounded, size: 15, color: onAccent),
                const SizedBox(width: 6),
                Text(
                  count == 1 ? '1 new post' : '$count new posts',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: onAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
