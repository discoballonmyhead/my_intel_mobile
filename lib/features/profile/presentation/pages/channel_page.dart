import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../../comments/presentation/pages/post_detail_page.dart';
import '../../../credibility/presentation/widgets/credibility_breakdown_sheet.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/quote_composer.dart';
import '../../../messaging/presentation/cubits/inbox_cubit.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../../reactions/presentation/widgets/reaction_bar.dart';
import '../../domain/entities/profile.dart';
import '../providers/transient_channel_cubit.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_ui.dart';
import 'profile_page.dart';

/// "OSINT analyst · Follows you": the line under someone else's name.
String channelSubtitle(Profile profile, {required bool followsYou}) => [
      profile.role.displayName,
      if (followsYou) 'Follows you',
    ].join('  ·  ');

/// Someone else's profile, addressed by username: the same calm header as
/// your own (with Follow and Message), then their posts drawn like the Feed.
/// State lives in a route-scoped [ChannelCubit] provided by the router.
class ChannelPage extends StatelessWidget {
  const ChannelPage({required this.username, super.key});

  final String username;

  Future<void> _message(BuildContext context, Profile profile) async {
    final inbox = context.read<InboxCubit>();
    final id = await inbox.openDirect(profile.id);
    if (!context.mounted) return;
    if (id != null) {
      unawaited(context.push(AppRoutes.chatFor(id)));
    } else {
      AppDialogs.snack(
          context, inbox.state.failure?.message ?? 'Could not open a chat.');
      inbox.clearFailure();
    }
  }

  Future<void> _share(BuildContext context, Post post) async {
    await Clipboard.setData(
        ClipboardData(text: '${Env.webAppUrl}/feed?highlight=${post.id}'));
    if (context.mounted) AppDialogs.snack(context, 'Link copied.');
  }

  Future<void> _quote(BuildContext context, ChannelCubit cubit, Post post,
      String? myUsername) async {
    final comment =
        await QuoteComposer.show(context, post, username: myUsername);
    if (comment == null) return;
    await cubit.toggleRepost(post, quote: comment);
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.select<AuthCubit, String?>((c) => c.state.user?.id);
    final isStaff = context.select<AccessCubit, bool>((c) => c.state.isStaff);

    return BlocConsumer<ChannelCubit, ChannelState>(
      listenWhen: (a, b) =>
          (b.followFailure != null && a.followFailure != b.followFailure) ||
          (b.profile != null && a.profile?.id != b.profile?.id),
      listener: (context, state) {
        // Your own name opens your Profile tab, not a stranger's view of it.
        if (state.profile != null && state.profile!.id == myId) {
          context.go(AppRoutes.profile);
          return;
        }
        final failure = state.followFailure;
        if (failure != null) {
          AppDialogs.snack(context, failure.message);
          context.read<ChannelCubit>().clearFollowFailure();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ChannelCubit>();
        final profile = state.profile;
        final Widget body;
        if (state.isLoading && profile == null) {
          body = const ProfileSkeleton();
        } else if (profile == null) {
          final notFound = state.failure is NotFoundFailure;
          body = ListView(children: [
            const SizedBox(height: 60),
            notFound
                ? SoftMessage(
                    icon: Icons.person_off_outlined,
                    title: 'This profile isn’t available',
                    body: 'It may have been deleted or renamed.',
                    action: 'Go back',
                    onAction: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.feed),
                  )
                : SoftMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Couldn’t load this profile',
                    body: state.failure?.message ??
                        'Check your connection and try again.',
                    action: 'Try again',
                    onAction: () => cubit.load(username),
                  ),
          ]);
        } else {
          body = RefreshIndicator(
            onRefresh: () => cubit.load(username),
            child: ContentColumn(
              padded: false,
              child: _profile(context, state, cubit, profile, myId),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  onReport: profile == null || profile.id == myId
                      ? null
                      : () => ReportSheet.show(
                            context,
                            targetType: ReportTargetType.profile,
                            targetId: profile.id,
                          ),
                  onAdmin: profile == null || !isStaff
                      ? null
                      : () => context.push(AppRoutes.adminUserFor(profile.id)),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profile(BuildContext context, ChannelState state, ChannelCubit cubit,
      Profile profile, String? myId) {
    final following = state.stats.isFollowing;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        ProfileHeader(
          profile: profile,
          stats: state.stats,
          subtitle:
              channelSubtitle(profile, followsYou: state.stats.followsYou),
          onFollowers: () => context.push(
              AppRoutes.followListFor(profile.id, 'followers'),
              extra: '@${profile.username}'),
          onFollowing: () => context.push(
              AppRoutes.followListFor(profile.id, 'following'),
              extra: '@${profile.username}'),
          onCredibility: state.credibility == null
              ? null
              : () => CredibilityBreakdownSheet.show(
                    context,
                    state.credibility!,
                    username: profile.username,
                  ),
          actions: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Pill(
                key: const Key('channel-follow'),
                label: following ? 'Following' : 'Follow',
                icon: following ? Icons.check_rounded : null,
                filled: !following,
                width: 120,
                onTap: cubit.toggleFollow,
              ),
              const SizedBox(width: 8),
              _Pill(
                key: const Key('channel-message'),
                label: 'Message',
                icon: Icons.mail_outline_rounded,
                outlined: true,
                onTap: () => _message(context, profile),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _PostsHeading(),
        if (state.posts.isEmpty)
          SoftMessage(
            icon: Icons.edit_note_rounded,
            title: 'No posts yet',
            body: 'When ${profile.username} posts, it shows up here.',
          )
        else
          for (final post in state.posts)
            PostCard(
              key: ValueKey('p${post.id}'),
              item: OriginalPost(post),
              myUserId: myId,
              onLike: () => cubit.toggleLike(post),
              onSave: () => cubit.toggleSave(post),
              onRepost: () => cubit.toggleRepost(post),
              onQuote: () => unawaited(_quote(context, cubit, post,
                  context.read<AuthCubit>().state.user?.username)),
              onShare: () => unawaited(_share(context, post)),
              onAuthorTap: (name) => name == profile.username
                  ? null
                  : unawaited(context.push(AppRoutes.channelFor(name))),
              onTap: () => unawaited(context.push(AppRoutes.postFor(post.id))),
              onComment: () => unawaited(context.push(
                  AppRoutes.postFor(post.id),
                  extra: const PostDetailArgs(focusComposer: true))),
              footer: post.isOsint ? ReactionBar(postId: post.id) : null,
            ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onReport, this.onAdmin});

  final VoidCallback? onReport;
  final VoidCallback? onAdmin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: palette.muted),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.feed),
          ),
          const Spacer(),
          if (onReport != null || onAdmin != null)
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              icon: Icon(Icons.more_horiz_rounded, color: palette.muted),
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: palette.border),
              ),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                if (onReport != null)
                  _menuItem(context, onReport!, Icons.flag_rounded,
                      'Report profile', palette.accent),
                if (onAdmin != null)
                  _menuItem(context, onAdmin!, Icons.admin_panel_settings,
                      'Open in admin', Theme.of(context).colorScheme.onSurface),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  PopupMenuItem<VoidCallback> _menuItem(BuildContext context,
          VoidCallback action, IconData icon, String label, Color color) =>
      PopupMenuItem(
        value: action,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(label, style: inter(15, color: color)),
          ],
        ),
      );
}

/// Follow (red), Following (grey with a tick) or Message (outlined).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.outlined = false,
    this.width,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final bool outlined;
  final double? width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fg = filled ? Colors.white : onSurface;
    return Semantics(
      button: true,
      child: Material(
        color: filled
            ? palette.accent
            : outlined
                ? Colors.transparent
                : palette.surface2,
        shape: StadiumBorder(
            side:
                outlined ? BorderSide(color: palette.border) : BorderSide.none),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 38,
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: inter(14, weight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single "Posts" label with the underline, matching the Profile tabs.
class _PostsHeading extends StatelessWidget {
  const _PostsHeading();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Posts',
                      style:
                          inter(15, weight: FontWeight.w600, color: onSurface)),
                  const SizedBox(height: 10),
                  Container(height: 2, width: 56, color: onSurface),
                ],
              ),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
