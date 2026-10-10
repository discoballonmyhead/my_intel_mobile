import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../domain/entities/message.dart';
import '../cubits/chat_cubit.dart';
import '../cubits/inbox_cubit.dart';
import '../widgets/chat_composer.dart';
import '../widgets/conversation_info_sheet.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final chat = context.read<ChatCubit>();
    context.read<InboxCubit>().markLocallyRead(chat.state.conversationId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // reverse: true → maxScrollExtent is the oldest end of the thread.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      context.read<ChatCubit>().loadMore();
    }
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final ok = await context.read<ChatCubit>().submit(text);
    if (ok && mounted) _controller.clear();
  }

  Future<void> _onMessageLongPress(Message message) async {
    final cubit = context.read<ChatCubit>();
    final myId = cubit.state.myUserId;
    final mine = message.isMine(myId);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () => Navigator.of(context).pop('reply'),
              ),
            if ((message.body ?? '').isNotEmpty && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            if (message.canEdit(myId))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Delete for me'),
              onTap: () => Navigator.of(context).pop('delete_me'),
            ),
            if (message.canDeleteForEveryone(myId))
              ListTile(
                leading: Icon(Icons.delete_forever_outlined,
                    color: context.palette.accent2),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.of(context).pop('delete_all'),
              ),
            if (!mine && !message.isDeleted && message.senderId != null)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: context.palette.warn),
                title: const Text('Report message'),
                onTap: () => Navigator.of(context).pop('report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'reply':
        cubit.startReply(message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
        if (mounted) AppDialogs.snack(context, 'Copied.');
      case 'edit':
        _controller.text = message.body ?? '';
        cubit.startEdit(message);
      case 'delete_me':
        await cubit.deleteMessage(message, forEveryone: false);
      case 'delete_all':
        {
          final ok = await AppDialogs.confirm(
            context,
            title: 'Delete for everyone?',
            message: 'Everyone in this conversation will see "Message deleted".',
            confirmLabel: 'DELETE',
            destructive: true,
          );
          if (ok) await cubit.deleteMessage(message, forEveryone: true);
        }
      case 'report':
        await ReportSheet.show(
          context,
          targetType: ReportTargetType.message,
          targetId: '${message.id}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (a, b) =>
          a.isClosedForMe != b.isClosedForMe ||
          (b.actionFailure != null && a.actionFailure != b.actionFailure),
      listener: (context, state) {
        if (state.isClosedForMe) {
          context.read<InboxCubit>().refresh();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.messages);
          }
          return;
        }
        final failure = state.actionFailure;
        if (failure != null) {
          AppDialogs.snack(context, failure.message);
          context.read<ChatCubit>().clearActionFailure();
        }
      },
      builder: (context, state) {
        final cubit = context.read<ChatCubit>();
        final conversation = state.conversation;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: conversation == null
                ? const Text('')
                : InkWell(
                    onTap: () => ConversationInfoSheet.show(context),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: state.title,
                          radius: 16,
                          icon: conversation.isGroup
                              ? Icons.groups_2_outlined
                              : state.recipientGone
                                  ? Icons.person_off_outlined
                                  : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            state.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.isMuted) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(Icons.notifications_off_outlined,
                              size: 14, color: context.palette.muted),
                        ],
                      ],
                    ),
                  ),
            actions: [
              if (conversation != null)
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => ConversationInfoSheet.show(context),
                ),
            ],
          ),
          body: switch (state.status) {
            ChatStatus.loading => const AppLoader(),
            ChatStatus.error => AppErrorView(
                failure: state.failure ?? const UnexpectedFailure(),
                onRetry: cubit.load,
              ),
            ChatStatus.ready => Column(
                children: [
                  Expanded(
                    child: state.messages.isEmpty
                        ? const AppEmptyView(
                            message: 'Say hello',
                            icon: Icons.waving_hand_outlined,
                          )
                        : _MessageList(
                            state: state,
                            scroll: _scroll,
                            onLongPress: _onMessageLongPress,
                          ),
                  ),
                  ChatComposer(
                    controller: _controller,
                    onSubmit: _submit,
                    isSending: state.isSending,
                    replyTo: state.replyTo,
                    replySenderName: state.replyTo == null
                        ? null
                        : state.senderName(state.replyTo!.senderId),
                    editing: state.editing,
                    onCancelReply: cubit.cancelReply,
                    onCancelEdit: () {
                      _controller.clear();
                      cubit.cancelEdit();
                    },
                    enabled: !state.recipientGone,
                    disabledHint: 'This account no longer exists',
                  ),
                ],
              ),
          },
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.scroll,
    required this.onLongPress,
  });

  final ChatState state;
  final ScrollController scroll;
  final ValueChanged<Message> onLongPress;

  @override
  Widget build(BuildContext context) {
    final isGroup = state.conversation?.isGroup ?? false;
    final seenUpTo = isGroup ? null : state.seenByOthersUpTo;
    // Only the newest of my messages that the other side has read gets a tick.
    final lastSeenMine = seenUpTo == null
        ? null
        : state.messages
            .where((m) => m.isMine(state.myUserId) && m.id <= seenUpTo)
            .map((m) => m.id)
            .fold<int?>(null, (a, b) => a == null || b > a ? b : a);

    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: AppLoader(),
          );
        }
        final message = state.messages[index];
        final mine = message.isMine(state.myUserId);
        final replyTo = state.messageById(message.replyToId);
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMine: mine,
          senderName: isGroup ? state.senderName(message.senderId) : null,
          replyTo: replyTo,
          replySenderName:
              replyTo == null ? null : state.senderName(replyTo.senderId),
          showSeen: mine && message.id == lastSeenMine,
          onLongPress: () => onLongPress(message),
        );
      },
    );
  }
}
