import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../e2ee/presentation/cubits/e2ee_cubit.dart';
import '../../../e2ee/presentation/widgets/e2ee_widgets.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../moderation/presentation/widgets/report_sheet.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/message.dart';
import '../cubits/chat_cubit.dart';
import '../cubits/inbox_cubit.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/messaging_ui.dart';
import 'conversation_info_page.dart';

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
    if (ok && mounted) {
      _controller.clear();
      unawaited(JumpToLatest.scrollToLatest(_scroll));
    }
  }

  void _sendFiles(List<PickedChatFile> files) {
    final text = _controller.text;
    _controller.clear();
    unawaited(context.read<ChatCubit>().sendFiles(files, text));
    unawaited(JumpToLatest.scrollToLatest(_scroll));
  }

  void _openInfo() {
    final cubit = context.read<ChatCubit>();
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const ConversationInfoPage(),
      ),
    )));
  }

  Future<void> _onLongPress(Message message, Rect rect) async {
    final cubit = context.read<ChatCubit>();
    final state = cubit.state;
    final myId = state.myUserId;
    final mine = message.isMine(myId);
    final hasText = (message.body ?? '').trim().isNotEmpty;

    // Nothing readable to reply to, copy or edit: only Delete.
    final locked = !message.isDeleted && !message.isReadable;
    final items = <(String, IconData, bool)>[
      if (locked)
        ('Delete', Icons.delete_outline_rounded, true)
      else ...[
        if (!message.isDeleted) ('Reply', Icons.reply_rounded, false),
        if (hasText && !message.isDeleted)
          ('Copy', Icons.content_copy_rounded, false),
        if (message.canEdit(myId) && hasText)
          ('Edit', Icons.edit_rounded, false),
        if (!mine && message.senderId != null && !message.isDeleted)
          ('View profile', Icons.person_outline_rounded, false),
        if (mine || message.isDeleted)
          ('Delete', Icons.delete_outline_rounded, true)
        else if (message.senderId != null)
          ('Report', Icons.flag_outlined, true),
      ],
    ];
    unawaited(HapticFeedback.mediumImpact());
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) => _MessageMenu(
        rect: rect,
        alignRight: mine,
        preview: BlocProvider.value(
          value: cubit,
          child: _bubbleFor(cubit.state, message, interactive: false),
        ),
        items: items,
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case 'Reply':
        cubit.startReply(message);
      case 'Copy':
        await Clipboard.setData(ClipboardData(text: message.body ?? ''));
        if (mounted) AppDialogs.snack(context, 'Copied.');
      case 'Edit':
        _controller.text = message.body ?? '';
        cubit.startEdit(message);
      case 'View profile':
        final name = state.senderName(message.senderId);
        unawaited(context.push(AppRoutes.channelFor(name)));
      case 'Report':
        await ReportSheet.show(
          context,
          targetType: ReportTargetType.message,
          targetId: '${message.id}',
        );
      case 'Delete':
        final forEveryone = message.canDeleteForEveryone(myId);
        final pick = await showConfirmSheet(
          context,
          title: 'Delete message?',
          body: forEveryone
              ? 'Delete it just for you, or for everyone in this chat.'
              : 'It’s removed for you only.',
          actions: [
            if (forEveryone)
              const SheetAction('Delete for everyone', destructive: true),
            SheetAction('Delete for me', destructive: !forEveryone),
          ],
        );
        if (pick == null) return;
        await cubit.deleteMessage(message,
            forEveryone: forEveryone && pick == 0);
    }
  }

  /// Long-press on a run of locked messages: delete them all, for you only.
  Future<void> _onLockedRunLongPress(List<Message> run) async {
    final cubit = context.read<ChatCubit>();
    unawaited(HapticFeedback.mediumImpact());
    final one = run.length == 1;
    final pick = await showConfirmSheet(
      context,
      title: one ? 'Delete message?' : 'Delete ${run.length} messages?',
      body: 'They can’t be read on this phone. They’re removed for you only.',
      actions: const [SheetAction('Delete for me', destructive: true)],
    );
    if (pick != 0 || !mounted) return;
    for (final m in run) {
      await cubit.deleteMessage(m, forEveryone: false);
    }
  }

  Widget _bubbleFor(ChatState state, Message message,
      {bool interactive = true,
      String? footer,
      bool showSender = false,
      bool showAvatar = false}) {
    final isGroup = state.conversation?.isGroup ?? false;
    final replyTo = state.messageById(message.replyToId);
    final bubble = MessageBubble(
      key: interactive ? ValueKey(message.id) : null,
      message: message,
      isMine: message.isMine(state.myUserId),
      senderName: isGroup ? state.senderName(message.senderId) : null,
      showSender: showSender,
      showAvatar: showAvatar || !interactive,
      replyTo: replyTo,
      replySenderName:
          replyTo == null ? null : state.senderName(replyTo.senderId),
      footer: footer,
      onLongPress: interactive ? (rect) => _onLongPress(message, rect) : null,
    );
    final canReply = interactive &&
        !message.isSystem &&
        !message.isDeleted &&
        message.isReadable;
    if (!canReply) return bubble;
    return SwipeToReply(
      key: ValueKey('swipe-${message.id}'),
      onReply: () => context.read<ChatCubit>().startReply(message),
      child: bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    final beforeRestore =
        context.select<E2eeCubit, bool>((c) => c.state.needsRestore);
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (a, b) =>
          a.isClosedForMe != b.isClosedForMe ||
          (b.actionFailure != null && a.actionFailure != b.actionFailure),
      listener: (context, state) {
        if (state.isClosedForMe) {
          context.read<InboxCubit>().refresh();
          Navigator.of(context).popUntil((r) => r is! MaterialPageRoute);
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
        final isGroup = conversation?.isGroup ?? false;
        return Scaffold(
          appBar: _ChatHeader(state: state, onInfo: _openInfo),
          body: switch (state.status) {
            ChatStatus.loading => const Center(
                child: SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5))),
            ChatStatus.error => Center(
                child: SoftMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Can’t load this chat',
                  body: state.failure?.message ??
                      'Check your connection and try again.',
                  action: 'Try again',
                  onAction: cubit.load,
                ),
              ),
            ChatStatus.ready => Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: state.messages.isEmpty && state.outgoing.isEmpty
                          ? _NewConversation(state: state)
                          : Stack(
                              children: [
                                _thread(state, beforeRestore: beforeRestore),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 16,
                                  child: Center(
                                    child: JumpToLatest(
                                      controller: _scroll,
                                      newestKey: state.messages.firstOrNull?.id,
                                      newestFromOthers: !(state
                                              .messages.firstOrNull
                                              ?.isMine(state.myUserId) ??
                                          true),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (conversation != null)
                    EncryptionNotice(
                      encrypted: conversation.isEncrypted,
                      waitingFor: [
                        for (final p
                            in conversation.membersWithoutKeys(state.myUserId))
                          p.displayName,
                      ],
                    ),
                  ChatComposer(
                    controller: _controller,
                    onSend: _submit,
                    onSendFiles: _sendFiles,
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
                    hint: isGroup ? 'Message the group' : 'Message',
                  ),
                ],
              ),
          },
        );
      },
    );
  }

  Widget _thread(ChatState state, {required bool beforeRestore}) {
    final messages = state.messages;
    final outgoing = state.outgoing.reversed.toList();
    final isGroup = state.conversation?.isGroup ?? false;
    final seenUpTo = isGroup ? null : state.seenByOthersUpTo;
    final lastSeenMine = seenUpTo == null
        ? null
        : messages
            .where((m) => m.isMine(state.myUserId) && m.id <= seenUpTo)
            .map((m) => m.id)
            .fold<int?>(null, (a, b) => a == null || b > a ? b : a);

    bool sameDay(DateTime a, DateTime b) {
      final x = a.toLocal(), y = b.toLocal();
      return x.year == y.year && x.month == y.month && x.day == y.day;
    }

    bool sameRun(Message a, Message? b) =>
        b != null &&
        !b.isSystem &&
        !a.isSystem &&
        a.senderId == b.senderId &&
        sameDay(a.createdAt, b.createdAt);

    // Newest first, like [messages]. Messages this phone can't read sit
    // together in one entry per day so they show as a single pill.
    final entries = groupLockedMessages(messages, sameDay: sameDay);
    final showRestore =
        beforeRestore && entries.any((e) => e.length > 1 || isLocked(e.first));

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      itemCount: outgoing.length +
          entries.length +
          (state.isLoadingMore ? 1 : 0) +
          (showRestore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < outgoing.length) {
          final o = outgoing[index];
          final cubit = context.read<ChatCubit>();
          return OutgoingBubble(
            key: ValueKey('out-${o.localId}'),
            outgoing: o,
            onRetry: () => unawaited(cubit.retryOutgoing(o.localId)),
            onRemove: () => cubit.removeOutgoing(o.localId),
          );
        }
        final i = index - outgoing.length;
        if (i >= entries.length) {
          if (state.isLoadingMore && i == entries.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return const _RestoreCard();
        }
        final entry = entries[i];
        final m = entry.first;
        final newer = i > 0 ? entries[i - 1].last : null;
        final older = i + 1 < entries.length ? entries[i + 1].first : null;
        final oldest = entry.last;
        final showDay =
            older == null || !sameDay(oldest.createdAt, older.createdAt);

        Widget item;
        if (isLocked(m)) {
          item = LockedRunPill(
            key: ValueKey('locked-${m.id}'),
            count: entry.length,
            beforeRestore: beforeRestore,
            onLongPress: () => _onLockedRunLongPress(entry),
          );
        } else {
          final runEnd = !sameRun(m, newer);
          final runStart = !sameRun(m, older);
          String? footer;
          if (runEnd && !m.isSystem && !m.isDeleted) {
            footer =
                messageFooter(m, prefix: m.id == lastSeenMine ? 'Read' : null);
          } else if (m.isEdited) {
            footer = 'Edited';
          }
          item = _bubbleFor(state, m,
              footer: footer, showSender: runStart, showAvatar: runEnd);
        }
        if (!showDay) return item;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [DayChip(day: oldest.createdAt.toLocal()), item],
        );
      },
    );
  }
}

/// A message this phone has no keys for (sent before a restore, or one that
/// failed to decrypt). Group messages still waiting for their key are not
/// locked: they arrive on their own.
bool isLocked(Message m) =>
    !m.isSystem &&
    !m.isDeleted &&
    (m.encryption == MessageEncryption.unavailable ||
        m.encryption == MessageEncryption.failed);

/// Splits [messages] (newest first) into entries: one per readable message,
/// and one per same-day run of locked messages.
List<List<Message>> groupLockedMessages(List<Message> messages,
    {required bool Function(DateTime, DateTime) sameDay}) {
  final entries = <List<Message>>[];
  for (final m in messages) {
    final last = entries.isEmpty ? null : entries.last;
    if (last != null &&
        isLocked(m) &&
        isLocked(last.last) &&
        sameDay(last.last.createdAt, m.createdAt)) {
      last.add(m);
    } else {
      entries.add([m]);
    }
  }
  return entries;
}

/// Top of a chat on a phone that hasn't restored its backup yet.
class _RestoreCard extends StatelessWidget {
  const _RestoreCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_reset_rounded, color: palette.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Older messages are locked on this phone',
                      style:
                          inter(15, weight: FontWeight.w600, color: onSurface)),
                  const SizedBox(height: 3),
                  Text('Restore with your backup PIN to read them here.',
                      style: inter(13, color: palette.muted, height: 1.4)),
                  const SizedBox(height: 12),
                  PillButton(
                    label: 'Restore',
                    width: 108,
                    height: 36,
                    onPressed: () => context.push(AppRoutes.restoreMessages),
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

/// Back, avatar, name with role or member count, and the info button.
class _ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const _ChatHeader({required this.state, required this.onInfo});

  final ChatState state;
  final VoidCallback onInfo;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final conversation = state.conversation;
    final isGroup = conversation?.isGroup ?? false;
    final other = conversation?.other(state.myUserId);
    final subtitle = conversation == null
        ? null
        : isGroup
            ? '${conversation.participants.length} members'
            : other?.profile?.role.displayName;
    final names = state.groupAvatarNames;

    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      shape: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.6))),
      title: conversation == null
          ? null
          : InkWell(
              onTap: onInfo,
              child: Row(
                children: [
                  if (isGroup)
                    GroupAvatar(names: names, size: 40)
                  else
                    UserAvatar(
                      name: state.title,
                      radius: 19,
                      icon: state.recipientGone
                          ? Icons.person_off_outlined
                          : null,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(state.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: inter(16,
                                      weight: FontWeight.w600,
                                      color: onSurface)),
                            ),
                            if (conversation.isMuted) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.notifications_off_outlined,
                                  size: 15, color: palette.muted),
                            ],
                          ],
                        ),
                        if (subtitle != null)
                          Text(subtitle,
                              style: inter(13, color: palette.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        if (conversation != null)
          IconButton(
            tooltip: isGroup ? 'Group info' : 'Chat info',
            icon: Icon(Icons.info_outline_rounded, color: palette.muted),
            onPressed: onInfo,
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// A chat with no messages yet: who you're talking to and "Say hi".
class _NewConversation extends StatelessWidget {
  const _NewConversation({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final other = state.conversation?.other(state.myUserId);
    final isGroup = state.conversation?.isGroup ?? false;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 90),
        Center(child: UserAvatar(name: state.title, radius: 40)),
        const SizedBox(height: 14),
        Text(state.title,
            textAlign: TextAlign.center,
            style: inter(19, weight: FontWeight.w600, color: onSurface)),
        if (!isGroup && other?.profile != null) ...[
          const SizedBox(height: 4),
          Text(other!.profile!.role.displayName,
              textAlign: TextAlign.center,
              style: inter(14, color: palette.muted)),
          const SizedBox(height: 16),
          Center(
            child: PillButton(
              label: 'View profile',
              soft: true,
              width: 140,
              height: 40,
              onPressed: () =>
                  context.push(AppRoutes.channelFor(other.displayName)),
            ),
          ),
        ],
        const SizedBox(height: 120),
        Text('Say hi 👋',
            textAlign: TextAlign.center,
            style: inter(14, color: palette.muted)),
      ],
    );
  }
}

/// The long-pressed message, lifted above a dimmed chat, with its actions
/// just below (or above, near the bottom of the screen).
class _MessageMenu extends StatelessWidget {
  const _MessageMenu({
    required this.rect,
    required this.alignRight,
    required this.preview,
    required this.items,
  });

  final Rect rect;
  final bool alignRight;
  final Widget preview;
  final List<(String, IconData, bool)> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final size = MediaQuery.sizeOf(context);
    const menuWidth = 230.0;
    final menuHeight = items.length * 48.0;
    final below = rect.bottom + 8 + menuHeight < size.height - 40;
    final menuTop = below ? rect.bottom + 8 : rect.top - 8 - menuHeight;
    final menuLeft = alignRight
        ? (rect.right - menuWidth).clamp(12.0, size.width - menuWidth - 12)
        : rect.left.clamp(12.0, size.width - menuWidth - 12);

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: rect.top - 3,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Material(type: MaterialType.transparency, child: preview),
            ),
          ),
        ),
        Positioned(
          left: menuLeft.toDouble(),
          top: menuTop.clamp(40.0, size.height - menuHeight - 20),
          width: menuWidth,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            elevation: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        indent: 16,
                        color: palette.border.withValues(alpha: 0.6)),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(items[i].$1),
                    child: SizedBox(
                      height: 47,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(items[i].$2,
                              size: 21,
                              color: items[i].$3 ? palette.accent : onSurface),
                          const SizedBox(width: 14),
                          Text(items[i].$1,
                              style: inter(15.5,
                                  color: items[i].$3
                                      ? palette.accent
                                      : onSurface)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
