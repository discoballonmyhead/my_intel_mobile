import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/quote_composer.dart';
import '../providers/profile_cubit.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_ui.dart';

/// Posts whose text contains every word of [query], ignoring case.
List<Post> searchPosts(List<Post> posts, String query) {
  final words =
      query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final p in posts)
      if (words.every((w) => p.body.toLowerCase().contains(w))) p,
  ];
}

/// The signed-in user's own profile: a calm header, then their posts and
/// saved posts drawn exactly like the Feed. Search filters their own posts.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _showSaved = false;
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _query.clear();
    });
  }

  Future<void> _edit(String username) async {
    final saved = await EditProfileSheet.show(context, username);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _quote(ProfileCubit cubit, Post post) async {
    final comment = await QuoteComposer.show(context, post,
        username: cubit.state.profile?.username);
    if (comment != null) await cubit.toggleRepost(post, quote: comment);
  }

  Future<void> _share(Post post) async {
    await Clipboard.setData(
        ClipboardData(text: '${Env.webAppUrl}/feed?highlight=${post.id}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            final cubit = context.read<ProfileCubit>();
            final profile = state.profile;
            return Column(
              children: [
                _TopBar(
                  searching: _searching,
                  query: _query,
                  enabled: profile != null,
                  onSearch: () => setState(() => _searching = true),
                  onCancel: _closeSearch,
                  onChanged: (_) => setState(() {}),
                ),
                Expanded(
                  child: profile == null
                      ? (state.failure != null && !state.isLoading
                          ? Center(
                              child: SoftMessage(
                                icon: Icons.wifi_off_rounded,
                                title: 'Can’t load your profile',
                                body: 'Check your connection and try again.',
                                action: 'Try again',
                                onAction: cubit.refresh,
                              ),
                            )
                          : const _ProfileSkeleton())
                      : RefreshIndicator(
                          onRefresh: cubit.refresh,
                          child: ContentColumn(
                            padded: false,
                            child: _searching
                                ? _results(context, state, cubit)
                                : _profile(context, state, cubit),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _postCard(BuildContext context, ProfileCubit cubit, FeedItem item) {
    final post = item.post;
    return PostCard(
      key: ValueKey(
          '${item is RepostedPost ? 'r${item.repostId}' : 'p'}${post.id}'),
      item: item,
      onLike: () => cubit.toggleLike(post),
      onSave: () => cubit.toggleSave(post),
      onRepost: () => cubit.toggleRepost(post),
      onQuote: () => unawaited(_quote(cubit, post)),
      myUserId: cubit.state.profile?.id,
      onShare: () => unawaited(_share(post)),
      onAuthorTap: (username) =>
          unawaited(context.push(AppRoutes.channelFor(username))),
    );
  }

  Widget _profile(
      BuildContext context, ProfileState state, ProfileCubit cubit) {
    final profile = state.profile!;
    final List<FeedItem> items = _showSaved
        ? [for (final p in state.savedPosts) OriginalPost(p)]
        : state.activity;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        ProfileHeader(
          profile: profile,
          stats: state.stats,
          onFollowers: () => context.push(AppRoutes.followers),
          onFollowing: () => context.push(AppRoutes.following),
          onEdit: () => _edit(profile.username),
        ),
        const SizedBox(height: 4),
        _Tabs(
          saved: _showSaved,
          onChanged: (saved) => setState(() => _showSaved = saved),
        ),
        if (items.isEmpty)
          _showSaved
              ? const SoftMessage(
                  icon: Icons.bookmark_border_rounded,
                  title: 'Nothing saved yet',
                  body: 'Tap the bookmark on any post to keep it here.',
                )
              : const SoftMessage(
                  icon: Icons.edit_note_rounded,
                  title: 'No posts yet',
                  body: 'What you post shows up here.',
                )
        else
          for (final item in items) _postCard(context, cubit, item),
      ],
    );
  }

  Widget _results(
      BuildContext context, ProfileState state, ProfileCubit cubit) {
    final palette = context.palette;
    final q = _query.text.trim();
    if (q.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 60),
        SoftMessage(
          icon: Icons.search_rounded,
          title: 'Search your posts',
          body: 'Find anything you’ve posted by a word or place.',
        ),
      ]);
    }
    final found = searchPosts(state.posts, q);
    if (found.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 60),
        SoftMessage(
          icon: Icons.search_off_rounded,
          title: 'No posts match “$q”',
          body: 'Try a different word.',
        ),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Text('${found.length} ${found.length == 1 ? 'post' : 'posts'}',
              style: inter(13, weight: FontWeight.w600, color: palette.muted)),
        ),
        Divider(height: 1, color: palette.border),
        for (final post in found) _postCard(context, cubit, OriginalPost(post)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searching,
    required this.query,
    required this.enabled,
    required this.onSearch,
    required this.onCancel,
    required this.onChanged,
  });

  final bool searching;
  final TextEditingController query;
  final bool enabled;
  final VoidCallback onSearch;
  final VoidCallback onCancel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (searching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: query,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style:
                    inter(16, color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search your posts',
                  hintStyle: inter(16, color: palette.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: palette.muted),
                  suffixIcon: query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon:
                              Icon(Icons.cancel_rounded, color: palette.muted),
                          onPressed: () {
                            query.clear();
                            onChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: palette.surface2,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  textStyle: inter(16, weight: FontWeight.w500)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            tooltip: 'Search your posts',
            icon: Icon(Icons.search_rounded, color: palette.muted),
            onPressed: enabled ? onSearch : null,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_rounded, color: palette.muted),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Posts / Saved, each half the width with an underline on the selected one.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.saved, required this.onChanged});

  final bool saved;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget tab(String label, bool value) {
      final on = saved == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            onTap: on ? null : () => onChanged(value),
            child: SizedBox(
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(label,
                      style: inter(15,
                          weight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? onSurface : palette.muted)),
                  const SizedBox(height: 10),
                  Container(
                    height: 2,
                    width: on ? label.length * 8.0 + 16 : 0,
                    color: onSurface,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(children: [tab('Posts', false), tab('Saved', true)]),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.palette.surface2;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: block, borderRadius: BorderRadius.circular(h / 2)),
        );
    Widget row() => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: block, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(140, 12),
                    const SizedBox(height: 12),
                    bar(double.infinity, 12),
                    const SizedBox(height: 8),
                    bar(220, 12),
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: block, shape: BoxShape.circle)),
        ),
        const SizedBox(height: 18),
        Center(child: bar(160, 20)),
        const SizedBox(height: 14),
        Center(child: bar(200, 12)),
        const SizedBox(height: 10),
        Center(child: bar(140, 12)),
        const SizedBox(height: 30),
        row(),
        row(),
        row(),
      ],
    );
  }
}
