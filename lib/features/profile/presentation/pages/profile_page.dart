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

/// Opens [location]; when the user comes back, reloads this profile so
/// follows, edits, deletes and saves made on that screen show up here.
Future<void> _pushThenRefresh(
  BuildContext context,
  String location, {
  Object? extra,
}) async {
  final cubit = context.read<ProfileCubit>();
  await context.push(location, extra: extra);
  if (!cubit.isClosed) await cubit.refresh();
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final roleColor = RoleBadge.colorOf(context, profile.role);
    final joined = profile.createdAt == null
        ? null
        : 'JOINED ${DateFormat('MMM yyyy').format(profile.createdAt!.toLocal()).toUpperCase()}';
    final meta = AppTypography.mono(size: 10, color: palette.muted, letterSpacing: 1);

    return Column(
      children: [
        UserAvatar(name: profile.username, radius: 44),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(profile.role.label, style: meta.copyWith(color: roleColor)),
            if (joined != null) Text('  ·  $joined', style: meta),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TextLink(
              label: 'Edit profile',
              onPressed: () => _EditUsernameDialog.show(context, profile.username),
            ),
            Text('|', style: TextStyle(color: palette.border)),
            _TextLink(
              label: 'View channel',
              onPressed: () => _pushThenRefresh(
                  context, AppRoutes.channelFor(profile.username)),
            ),
          ],
        ),
      ],
    );
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Stat(
          value: stats.followers,
          label: 'FOLLOWERS',
          onTap: () => _pushThenRefresh(
            context,
            AppRoutes.followListFor(profile.id, FollowListKind.followers.value),
            extra: '@${profile.username}',
          ),
        ),
        _Stat(
          value: stats.following,
          label: 'FOLLOWING',
          onTap: () => _pushThenRefresh(
            context,
            AppRoutes.followListFor(profile.id, FollowListKind.following.value),
            extra: '@${profile.username}',
          ),
        ),
        _Stat(value: profile.auraPoints, label: 'AURA'),
        if (profile.isAnalyst)
          _Stat(
            value: profile.score,
            label: 'CRED',
            labelColor: _bandColor(palette, profile.band),
          ),
      ],
    );
  }

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.labelColor,
    this.onTap,
  });

  Future<void> _share(Post post) async {
    await Clipboard.setData(
        ClipboardData(text: '${Env.webAppUrl}/feed?highlight=${post.id}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied.')));
  }

  /// Followers / following open the people list.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.mono(
            size: 9,
            color: labelColor ?? context.palette.muted,
            letterSpacing: 1,
          ),
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: content,
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? onSurface : context.palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.showAuthor});

  final Post post;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    final author = post.author?.username;
    final time = post.isEdited
        ? '${post.createdAt.timeAgo} · edited'
        : post.createdAt.timeAgo;
    final metaStyle = AppTypography.mono(size: 10, color: context.palette.muted);

    // Tap the row → the post with its comments; tap "@author" (Saved tab)
    // → that person's channel.
    return InkWell(
      onTap: () => _pushThenRefresh(context, AppRoutes.postFor(post.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showAuthor && author != null)
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _pushThenRefresh(context, AppRoutes.channelFor(author)),
                    child: Text('@$author',
                        style: metaStyle.copyWith(
                            color: context.palette.accent)),
                  ),
                  Text(' · $time', style: metaStyle),
                ],
              )
            else
              Text(time, style: metaStyle),
            const SizedBox(height: AppSpacing.xs),
            Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EditUsernameDialog extends StatefulWidget {
  const _EditUsernameDialog({required this.initial});

  final String initial;

  static Future<void> show(BuildContext context, String current) {
    final cubit = context.read<ProfileCubit>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _EditUsernameDialog(initial: current),
      ),
    );
  }

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Username can’t be empty.');
      return;
    }
    if (name == widget.initial) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final cubit = context.read<ProfileCubit>();
    final ok = await cubit.updateUsername(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = cubit.state.failure?.message ?? 'Could not update username.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Username',
          helperText: 'Your channel link changes too.',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
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
