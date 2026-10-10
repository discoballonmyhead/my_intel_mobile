import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../feed/domain/entities/post.dart';
import '../../domain/entities/profile.dart';

/// The signed-in user's own profile tab. Sign out and My reports live in
/// Settings; this screen is identity, standing and activity.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final cubit = context.read<ProfileCubit>();
          final profile = state.profile;

          if (profile == null) {
            if (state.failure != null && !state.isLoading) {
              return AppErrorView(
                failure: state.failure ?? const UnexpectedFailure(),
                onRetry: cubit.refresh,
              );
            }
            return const AppLoader();
          }

          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ContentColumn(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm, AppSpacing.lg, AppSpacing.sm, AppSpacing.xxxl),
                children: [
                  _Header(profile: profile),
                  const SizedBox(height: AppSpacing.xxl),
                  _Stats(profile: profile, stats: state.stats),
                  const SizedBox(height: AppSpacing.xxl),
                  _StatusLine(profile: profile, application: state.application),
                  const SizedBox(height: AppSpacing.xl),
                  _ActivityTabs(posts: state.posts, saved: state.savedPosts),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.profile, required this.stats});

  final Profile profile;
  final FollowStats stats;

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
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.labelColor,
    this.onTap,
  });

  final int value;
  final String label;
  final Color? labelColor;

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
      ],
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
}

Color _bandColor(AppPalette palette, CredibilityBand band) => switch (band) {
      CredibilityBand.high => palette.verified,
      CredibilityBand.moderate => palette.warn,
      CredibilityBand.low || CredibilityBand.poor => palette.accent2,
      CredibilityBand.unrated => palette.muted,
    };

/// One quiet line under the stats: the user's next step or standing.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.profile, required this.application});

  final Profile profile;
  final OsintApplication? application;

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessCubit>().state;
    final isAdmin = access.isAdmin || profile.role.isAdmin;
    final isStaff = access.isStaff || isAdmin;

    return Column(
      children: [
        if (profile.isAnalyst) _CredibilityBar(profile: profile),
        if (profile.isAnalyst && isStaff) const SizedBox(height: AppSpacing.lg),
        if (isStaff)
          _LineRow(
            title: isAdmin ? 'Admin console' : 'Moderation',
            action: 'Open →',
            onTap: () => context.push(AppRoutes.admin),
          ),
        if (!profile.isAnalyst && !isStaff) _applicationRow(context),
      ],
    );
  }

  Widget _applicationRow(BuildContext context) {
    final palette = context.palette;
    final app = application;
    void apply() => context.push(AppRoutes.applyOsint);

    if (app == null) {
      return _LineRow(
        title: 'Become an OSINT analyst',
        action: 'Apply →',
        onTap: apply,
      );
    }
    if (app.isPending) {
      return _LineRow(
        title: 'Analyst application',
        trailing: _Tag(label: 'IN REVIEW', color: palette.warn),
      );
    }
    if (app.isRejected) {
      if (app.canReapply()) {
        return _LineRow(
          title: 'Application not approved',
          action: 'Apply again →',
          onTap: apply,
        );
      }
      final from = DateFormat('d MMM').format(app.reapplyAvailableAt!.toLocal());
      return _LineRow(
        title: 'Application not approved',
        trailing: Text(
          'Reapply from $from',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.title, this.action, this.trailing, this.onTap});

  final String title;
  final String? action;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (action != null)
              Text(
                action!,
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.mono(size: 10, color: color, letterSpacing: 1)),
      ],
    );
  }
}

/// Score on the -50..100 scale with the distance to the next band.
class _CredibilityBar extends StatelessWidget {
  const _CredibilityBar({required this.profile});

  final Profile profile;

  static const _min = -50;
  static const _max = 100;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final score = profile.score;
    final fill = ((score - _min) / (_max - _min)).clamp(0.0, 1.0);
    final color = _bandColor(palette, profile.band);

    final (int, String)? next = switch (profile.band) {
      CredibilityBand.poor => (25, 'Low'),
      CredibilityBand.low => (50, 'Moderate'),
      CredibilityBand.moderate => (75, 'High'),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Credibility',
                  style: theme.textTheme.bodySmall),
            ),
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: '$score',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (next != null) ...[
                    TextSpan(
                      text: ' · ${next.$1 - score} to ',
                      style: TextStyle(color: palette.muted),
                    ),
                    TextSpan(
                      text: next.$2,
                      style: TextStyle(
                        color: _bandColor(palette, _bandFor(next.$1)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 3,
            color: color,
            backgroundColor: palette.surface2,
          ),
        ),
      ],
    );
  }

  static CredibilityBand _bandFor(int threshold) => switch (threshold) {
        >= 75 => CredibilityBand.high,
        >= 50 => CredibilityBand.moderate,
        _ => CredibilityBand.low,
      };
}

class _ActivityTabs extends StatefulWidget {
  const _ActivityTabs({required this.posts, required this.saved});

  final List<Post> posts;
  final List<Post> saved;

  @override
  State<_ActivityTabs> createState() => _ActivityTabsState();
}

class _ActivityTabsState extends State<_ActivityTabs> {
  bool _showSaved = false;

  @override
  Widget build(BuildContext context) {
    final items = _showSaved ? widget.saved : widget.posts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Tab(
              label: 'Posts',
              selected: !_showSaved,
              onTap: () => setState(() => _showSaved = false),
            ),
            const SizedBox(width: AppSpacing.xl),
            _Tab(
              label: 'Saved',
              selected: _showSaved,
              onTap: () => setState(() => _showSaved = true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          AppEmptyView(
            message: _showSaved ? 'Nothing saved yet' : 'No posts yet',
            icon: _showSaved
                ? Icons.bookmark_border_rounded
                : Icons.article_outlined,
          )
        else
          for (final post in items) _PostRow(post: post, showAuthor: _showSaved),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? onSurface : Colors.transparent,
                width: 2,
              ),
            ),
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
      ],
    );
  }
}
