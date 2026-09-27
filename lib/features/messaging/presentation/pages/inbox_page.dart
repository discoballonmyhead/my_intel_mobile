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
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/conversation.dart';
import '../cubits/inbox_cubit.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  Future<void> _showActions(BuildContext context, InboxEntry entry) async {
    final cubit = context.read<InboxCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(entry.isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined),
              title: Text(entry.isMuted ? 'Unmute' : 'Mute'),
              onTap: () => Navigator.of(context).pop('mute'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.palette.accent2),
              title: const Text('Delete conversation'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'mute') {
      await cubit.toggleMute(entry);
    } else if (action == 'delete') {
      final ok = await AppDialogs.confirm(
        context,
        title: 'Delete conversation?',
        message: 'It is removed for you only. The other side keeps their copy '
            'until they delete it too.',
        confirmLabel: 'DELETE',
        destructive: true,
      );
      if (ok) await cubit.deleteConversation(entry.conversationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MESSAGES')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New message',
        onPressed: () => context.push(AppRoutes.newMessage),
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: BlocConsumer<InboxCubit, InboxState>(
        listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
        listener: (context, state) {
          if (state.status == InboxStatus.ready && state.failure != null) {
            AppDialogs.snack(context, state.failure!.message);
            context.read<InboxCubit>().clearFailure();
          }
        },
        builder: (context, state) {
          final cubit = context.read<InboxCubit>();
          return RefreshIndicator(
            onRefresh: cubit.refresh,
            child: switch (state.status) {
              InboxStatus.idle || InboxStatus.loading =>
                const AppLoader(label: 'Loading messages'),
              InboxStatus.error => AppErrorView(
                  failure: state.failure ?? const UnexpectedFailure(),
                  onRetry: cubit.load,
                ),
              InboxStatus.ready when state.isEmpty => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    AppEmptyView(
                      message: 'No conversations yet',
                      icon: Icons.forum_outlined,
                    ),
                  ],
                ),
              InboxStatus.ready => ContentColumn(
                  padded: false,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: state.entries.length,
                    itemBuilder: (context, index) {
                      final entry = state.entries[index];
                      return _InboxTile(
                        entry: entry,
                        myUserId: state.userId,
                        onTap: () => context
                            .push(AppRoutes.chatFor(entry.conversationId)),
                        onLongPress: () => _showActions(context, entry),
                      );
                    },
                  ),
                ),
            },
          );
        },
      ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.entry,
    required this.myUserId,
    required this.onTap,
    required this.onLongPress,
  });

  final InboxEntry entry;
  final String? myUserId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final unread = entry.hasUnread;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            UserAvatar(
              name: entry.displayName,
              radius: 22,
              icon: entry.isGroup
                  ? Icons.groups_2_outlined
                  : entry.otherUserId == null
                      ? Icons.person_off_outlined
                      : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (entry.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.xs),
                          child: Icon(Icons.notifications_off_outlined,
                              size: 12, color: palette.muted),
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        entry.lastActivityAt.timeAgo,
                        style: AppTypography.mono(
                          size: 9,
                          color: unread ? palette.accent : palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.preview(myUserId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: unread ? null : palette.muted,
                            fontStyle: entry.lastMessageDeleted
                                ? FontStyle.italic
                                : null,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entry.isMuted
                                ? palette.muted
                                : palette.accent,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(
                            entry.unreadCount > 99
                                ? '99+'
                                : '${entry.unreadCount}',
                            style: AppTypography.mono(
                              size: 9,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
