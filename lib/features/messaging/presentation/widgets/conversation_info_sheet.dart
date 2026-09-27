import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/conversation.dart';
import '../cubits/chat_cubit.dart';

/// Members, mute, rename, add/remove, leave and delete — everything about the
/// conversation itself rather than a single message.
class ConversationInfoSheet extends StatelessWidget {
  const ConversationInfoSheet._();

  static Future<void> show(BuildContext context) {
    final cubit = context.read<ChatCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ConversationInfoSheet._(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final cubit = context.read<ChatCubit>();
        final conversation = state.conversation;
        if (conversation == null) return const SizedBox.shrink();
        final canManage = conversation.isGroup && conversation.myRole.canManage;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              Center(
                child: UserAvatar(
                  name: state.title,
                  radius: 30,
                  icon: conversation.isGroup ? Icons.groups_2_outlined : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(state.title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (canManage)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename group'),
                  onTap: () async {
                    final title = await AppDialogs.reason(
                      context,
                      title: 'Group name',
                      hint: 'Name',
                      confirmLabel: 'SAVE',
                      initialValue: conversation.title,
                      maxLength: 100,
                      maxLines: 1,
                    );
                    if (title != null) await cubit.renameGroup(title);
                  },
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_off_outlined),
                title: const Text('Mute notifications'),
                value: conversation.isMuted,
                onChanged: (muted) => cubit.setMuted(muted),
              ),
              if (conversation.isGroup) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      '${conversation.participants.length} MEMBERS',
                      style: AppTypography.mono(
                          size: 10, color: palette.muted, letterSpacing: 1.5),
                    ),
                    const Spacer(),
                    if (canManage)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push(
                              AppRoutes.addMembersFor(conversation.id));
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined,
                            size: 16),
                        label: const Text('ADD'),
                      ),
                  ],
                ),
                ...conversation.participants.map((p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(name: p.displayName),
                      title: Text(p.userId == state.myUserId
                          ? '${p.displayName} (you)'
                          : p.displayName),
                      subtitle: p.role == ParticipantRole.member
                          ? null
                          : Text(p.role.name.toUpperCase(),
                              style: AppTypography.mono(
                                  size: 9, color: palette.accent)),
                      onTap: p.profile == null || p.userId == state.myUserId
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              context.push(
                                  AppRoutes.channelFor(p.profile!.username));
                            },
                      trailing: canManage &&
                              p.userId != state.myUserId &&
                              p.role != ParticipantRole.owner
                          ? IconButton(
                              icon: Icon(Icons.person_remove_outlined,
                                  color: palette.accent2),
                              onPressed: () async {
                                final ok = await AppDialogs.confirm(
                                  context,
                                  title: 'Remove ${p.displayName}?',
                                  message:
                                      'They will stop receiving messages from this group.',
                                  confirmLabel: 'REMOVE',
                                  destructive: true,
                                );
                                if (ok) await cubit.removeMember(p.userId);
                              },
                            )
                          : null,
                    )),
              ] else if (conversation.other(state.myUserId)?.profile != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('View profile'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.channelFor(
                        conversation.other(state.myUserId)!.profile!.username));
                  },
                ),
              const Divider(height: AppSpacing.xl),
              if (conversation.isGroup)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded, color: palette.accent2),
                  title: const Text('Leave group'),
                  onTap: () async {
                    final ok = await AppDialogs.confirm(
                      context,
                      title: 'Leave group?',
                      message: 'You will no longer see new messages here.',
                      confirmLabel: 'LEAVE',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).pop();
                    await cubit.leave();
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline_rounded,
                    color: palette.accent2),
                title: const Text('Delete conversation'),
                subtitle: const Text('Removes it for you only'),
                onTap: () async {
                  final ok = await AppDialogs.confirm(
                    context,
                    title: 'Delete conversation?',
                    message: 'The history is removed for you. Others keep '
                        'their copy until they delete it too.',
                    confirmLabel: 'DELETE',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  Navigator.of(context).pop();
                  await cubit.deleteConversation();
                },
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}
