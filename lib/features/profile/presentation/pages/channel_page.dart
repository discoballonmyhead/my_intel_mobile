import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../../messaging/presentation/cubits/inbox_cubit.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../domain/entities/profile.dart';
import '../providers/transient_channel_cubit.dart';

/// Another user's channel, addressed by username. State lives in a
/// route-scoped [ChannelCubit] provided by the router.
class ChannelPage extends StatelessWidget {
  const ChannelPage({required this.username, super.key});

  final String username;

  Future<void> _message(BuildContext context, Profile profile) async {
    final inbox = context.read<InboxCubit>();
    final id = await inbox.openDirect(profile.id);
    if (!context.mounted) return;
    if (id != null) {
      context.push(AppRoutes.chatFor(id));
    } else {
      AppDialogs.snack(
          context, inbox.state.failure?.message ?? 'Could not open a chat.');
      inbox.clearFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final myId = context.select<AuthCubit, String?>((c) => c.state.user?.id);
    final isStaff = context.select<AccessCubit, bool>((c) => c.state.isStaff);

    return BlocConsumer<ChannelCubit, ChannelState>(
      listenWhen: (a, b) =>
          b.followFailure != null && a.followFailure != b.followFailure,
      listener: (context, state) {
        AppDialogs.snack(context, state.followFailure!.message);
        context.read<ChannelCubit>().clearFollowFailure();
      },
      builder: (context, state) {
        final cubit = context.read<ChannelCubit>();
        final profile = state.profile;
        final isMe = profile != null && profile.id == myId;

        return Scaffold(
          appBar: AppBar(
            title: Text('@$username'.toUpperCase()),
            actions: [
              if (profile != null && !isMe)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'report':
                        ReportSheet.show(
                          context,
                          targetType: ReportTargetType.profile,
                          targetId: profile.id,
                        );
                      case 'admin':
                        context.push(AppRoutes.adminUserFor(profile.id));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'report', child: Text('Report profile')),
                    if (isStaff)
                      const PopupMenuItem(
                          value: 'admin', child: Text('Open in admin')),
                  ],
                ),
            ],
          ),
          body: state.isLoading
              ? const AppLoader()
              : profile == null
                  ? AppErrorView(
                      failure: state.failure ?? const NotFoundFailure(),
                      onRetry: () => cubit.load(username),
                    )
                  : RefreshIndicator(
                      onRefresh: () => cubit.load(username),
                      child: ContentColumn(
                        padded: false,
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: palette.surface2,
                                        child: Text(
                                          profile.username.characters.first
                                              .toUpperCase(),
                                          style: AppTypography.mono(
                                            size: 17,
                                            color: palette.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile.username,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(
                                                height: AppSpacing.xs),
                                            Wrap(
                                              spacing: AppSpacing.xs,
                                              children: [
                                                RoleBadge(role: profile.role),
                                                if (state.stats.followsYou &&
                                                    !isMe)
                                                  Text(
                                                    'FOLLOWS YOU',
                                                    style: AppTypography.mono(
                                                      size: 9,
                                                      color: palette.muted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isMe) ...[
                                        IconButton.outlined(
                                          tooltip: 'Message',
                                          onPressed: () =>
                                              _message(context, profile),
                                          icon: const Icon(
                                              Icons.mail_outline_rounded,
                                              size: 18),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        FilledButton(
                                          onPressed: cubit.toggleFollow,
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size(104, 38),
                                            backgroundColor:
                                                state.stats.isFollowing
                                                    ? palette.surface2
                                                    : palette.accent,
                                            foregroundColor:
                                                state.stats.isFollowing
                                                    ? palette.muted
                                                    : null,
                                          ),
                                          child: Text(
                                            state.stats.isFollowing
                                                ? 'FOLLOWING'
                                                : 'FOLLOW',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Row(
                                    children: [
                                      _Metric(
                                        label: 'FOLLOWERS',
                                        value: state.stats.followers,
                                        onTap: () => context.push(
                                          AppRoutes.followListFor(
                                              profile.id, 'followers'),
                                          extra: '@${profile.username}',
                                        ),
                                      ),
                                      _Metric(
                                        label: 'FOLLOWING',
                                        value: state.stats.following,
                                        onTap: () => context.push(
                                          AppRoutes.followListFor(
                                              profile.id, 'following'),
                                          extra: '@${profile.username}',
                                        ),
                                      ),
                                      if (profile.isAnalyst)
                                        _Metric(
                                            label: 'CRED',
                                            value: profile.score),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Divider(color: palette.border, height: 1),
                            if (state.posts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.xxl),
                                child: AppEmptyView(message: 'No posts yet'),
                              )
                            else
                              ...state.posts.map((p) => InkWell(
                                  onTap: () =>
                                      context.push(AppRoutes.postFor(p.id)),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom:
                                            BorderSide(color: palette.border),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.isEdited
                                              ? '${p.createdAt.timeAgo} · edited'
                                              : p.createdAt.timeAgo,
                                          style: AppTypography.mono(
                                            size: 9,
                                            color: palette.muted,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          p.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        if (p.replyCount > 0) ...[
                                          const SizedBox(
                                              height: AppSpacing.xs),
                                          Text(
                                            '${p.replyCount} COMMENT'
                                            '${p.replyCount == 1 ? '' : 'S'}',
                                            style: AppTypography.mono(
                                              size: 9,
                                              color: palette.muted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleMedium),
              Text(
                label,
                style: AppTypography.mono(
                  size: 9,
                  color: context.palette.muted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
