import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/mint_logo.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../../e2ee/presentation/widgets/e2ee_widgets.dart';
import '../../domain/entities/conversation.dart';
import '../cubits/inbox_cubit.dart';
import '../widgets/messaging_ui.dart';

/// The Messages tab: Chats / Groups tabs and the conversation list.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  bool _groups = false;

  Future<void> _showActions(InboxEntry entry) async {
    final cubit = context.read<InboxCubit>();
    final choice = await showChoiceSheet(context, actions: [
      SheetAction(entry.isMuted ? 'Unmute' : 'Mute',
          icon: entry.isMuted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined),
      const SheetAction('Delete conversation',
          icon: Icons.delete_outline_rounded, destructive: true),
    ]);
    if (!mounted || choice == null) return;
    if (choice == 0) {
      await cubit.toggleMute(entry);
      return;
    }
    final ok = await showConfirmSheet(
      context,
      title: 'Delete conversation?',
      body: entry.isGroup
          ? 'It’s removed from your inbox. Others in the group keep their copy.'
          : 'It’s removed from your inbox. ${entry.displayName} still has '
              'their copy.',
      actions: const [SheetAction('Delete', destructive: true)],
    );
    if (ok == 0) await cubit.deleteConversation(entry.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<InboxCubit, InboxState>(
          listenWhen: (a, b) => b.failure != null && a.failure != b.failure,
          listener: (context, state) {
            if (state.status == InboxStatus.ready && state.failure != null) {
              AppDialogs.snack(context, state.failure!.message);
              context.read<InboxCubit>().clearFailure();
            }
          },
          builder: (context, state) {
            final cubit = context.read<InboxCubit>();
            return ContentColumn(
              padded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _title(context),
                  const E2eeInboxBanner(),
                  _Tabs(
                    groups: _groups,
                    chatsUnread: _unread(state, groups: false),
                    groupsUnread: _unread(state, groups: true),
                    onChanged: (g) => setState(() => _groups = g),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cubit.refresh,
                      child: _list(context, state, cubit),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _unread(InboxState state, {required bool groups}) => state.entries
      .where((e) => e.isGroup == groups && !e.isMuted)
      .fold(0, (sum, e) => sum + e.unreadCount);

  /// The MINT logo with ✎ on the right, like the Feed header: New message on
  /// the Chats tab, New group on the Groups tab.
  Widget _title(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const MintLogo(height: 30, animate: false),
          Positioned(
            right: 6,
            child: IconButton(
              tooltip: _groups ? 'New group' : 'New message',
              icon: const Icon(Icons.edit_square),
              onPressed: () => context.push(_groups
                  ? '${AppRoutes.newMessage}?group=1'
                  : AppRoutes.newMessage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, InboxState state, InboxCubit cubit) {
    switch (state.status) {
      case InboxStatus.idle || InboxStatus.loading:
        return const _InboxSkeleton();
      case InboxStatus.error:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            SoftMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Can’t load messages',
              body: 'Check your connection and try again.',
              action: 'Try again',
              onAction: cubit.load,
            ),
          ],
        );
      case InboxStatus.ready:
        break;
    }
    final entries = state.entries.where((e) => e.isGroup == _groups).toList();
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          _groups
              ? SoftMessage(
                  icon: Icons.groups_rounded,
                  title: 'No groups yet',
                  body: 'Start a group to talk with several people at once.',
                  action: 'New group',
                  filledAction: true,
                  onAction: () =>
                      context.push('${AppRoutes.newMessage}?group=1'),
                )
              : SoftMessage(
                  icon: Icons.forum_rounded,
                  title: 'No messages yet',
                  body: 'Start a conversation with anyone on MINT.',
                  action: 'New message',
                  filledAction: true,
                  onAction: () => context.push(AppRoutes.newMessage),
                ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in entries)
          InboxRow(
            entry: entry,
            myUserId: state.userId,
            onTap: () => context.push(AppRoutes.chatFor(entry.conversationId)),
            onLongPress: () => _showActions(entry),
          ),
      ],
    );
  }
}

/// Chats / Groups, half the width each, with an underline and unread counts.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.groups,
    required this.chatsUnread,
    required this.groupsUnread,
    required this.onChanged,
  });

  final bool groups;
  final int chatsUnread;
  final int groupsUnread;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget tab(String label, bool value, int unread) {
      final on = groups == value;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: inter(15,
                              weight: on ? FontWeight.w600 : FontWeight.w400,
                              color: on ? onSurface : palette.muted)),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        _CountPill(count: unread),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 2.5,
                    width: on ? 56 : 0,
                    decoration: BoxDecoration(
                        color: onSurface,
                        borderRadius: BorderRadius.circular(2)),
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
      child: Row(children: [
        tab('Chats', false, chatsUnread),
        tab('Groups', true, groupsUnread),
      ]),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.muted = false});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? palette.muted : palette.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: inter(12, weight: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// One conversation: avatar, name, last message, time and unread count.
class InboxRow extends StatelessWidget {
  const InboxRow({
    required this.entry,
    required this.myUserId,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final InboxEntry entry;
  final String? myUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final unread = entry.hasUnread;
    final preview = entry.preview(myUserId);
    final previewStyle = inter(14.5, color: unread ? onSurface : palette.muted);
    final attachmentIcon = !entry.lastIsAttachment
        ? null
        : switch (entry.lastAttachmentType) {
            'image' => Icons.photo_camera_outlined,
            'video' => Icons.videocam_outlined,
            'file' => Icons.description_outlined,
            _ => Icons.attach_file_rounded,
          };

    return Semantics(
      identifier: 'inbox-row',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: [
              entry.isGroup
                  ? GroupAvatar(names: entry.groupAvatarNames(myUserId))
                  : UserAvatar(
                      name: entry.displayName,
                      radius: 26,
                      icon: entry.otherUserId == null
                          ? Icons.person_off_outlined
                          : null,
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: inter(16,
                                  weight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: onSurface)),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.lastActivityAt.timeAgo,
                            style: inter(13,
                                color: unread && !entry.isMuted
                                    ? palette.accent
                                    : palette.muted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (attachmentIcon != null) ...[
                          Icon(attachmentIcon, size: 16, color: palette.muted),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: previewStyle.copyWith(
                                  fontStyle: entry.lastMessageDeleted
                                      ? FontStyle.italic
                                      : null)),
                        ),
                        if (entry.isMuted)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.notifications_off_outlined,
                                size: 17, color: palette.muted),
                          ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          _CountPill(
                              count: entry.unreadCount, muted: entry.isMuted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A second initial for the group avatar: the last sender is unknown here,
  /// so use the next letter of the title for variety.
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.palette.surface2;
    Widget bar(double w) => Container(
          width: w,
          height: 12,
          decoration: BoxDecoration(
              color: block, borderRadius: BorderRadius.circular(6)),
        );
    const widths = <(double, double)>[
      (140, 230),
      (110, 200),
      (160, 250),
      (120, 180)
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final (a, b) in widths)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            child: Row(
              children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(color: block, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(a), const SizedBox(height: 12), bar(b)],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
