import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/post_attachments.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/entities/message.dart';
import '../cubits/chat_cubit.dart';
import 'messaging_ui.dart';

/// Width of photos, videos and files in a chat.
const double kChatMediaWidth = 240;

/// One message. Mine sit on the right in red; theirs on the left in grey,
/// with the sender's avatar and name in groups. Photos, videos and files are
/// drawn above the text, which becomes their caption.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.showSender = false,
    this.showAvatar = false,
    this.replyTo,
    this.replySenderName,
    this.footer,
    this.onLongPress,
    super.key,
  });

  final Message message;
  final bool isMine;

  /// The sender's name, for groups.
  final String? senderName;

  /// First message in a run from this sender (groups): show the name.
  final bool showSender;

  /// Last message in a run from this sender (groups): show the avatar.
  final bool showAvatar;
  final Message? replyTo;
  final String? replySenderName;

  /// Small line under the message, e.g. "Read" or "Edited · 10:42".
  final String? footer;

  /// Called with the message's place on screen, to anchor the menu.
  final ValueChanged<Rect>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (message.isSilentSystem) return const SizedBox.shrink();
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(message.preview,
              textAlign: TextAlign.center,
              style: inter(12.5, color: palette.muted)),
        ),
      );
    }

    final group = senderName != null && !isMine;
    final body = (message.body ?? '').trim();
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;

    Widget content;
    if (message.isDeleted) {
      content = _DeletedPill(
        text: message.removedByModerator
            ? 'Removed by moderators'
            : isMine
                ? 'You deleted this message'
                : 'This message was deleted',
      );
    } else if (!message.isReadable) {
      // Encrypted but not readable here: show the status like a deleted one.
      content =
          _DeletedPill(text: message.preview, icon: Icons.lock_outline_rounded);
    } else {
      content = Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.attachments.isNotEmpty)
            SizedBox(
              width: kChatMediaWidth,
              child: PostAttachments(
                  attachments: asPostAttachments(message.attachments)),
            ),
          if (message.attachments.isNotEmpty && body.isNotEmpty)
            const SizedBox(height: 4),
          if (body.isNotEmpty || replyTo != null)
            _TextBubble(
              isMine: isMine,
              body: body,
              replyTo: replyTo,
              replySenderName: replySenderName,
              maxWidth: maxWidth,
            ),
        ],
      );
    }

    final withLongPress = Builder(
      builder: (inner) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress == null || (message.isDeleted && !isMine)
            ? null
            : () {
                final box = inner.findRenderObject()! as RenderBox;
                onLongPress!(box.localToGlobal(Offset.zero) & box.size);
              },
        child: content,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: showSender ? 10 : 3, bottom: 3),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (group)
            Padding(
              padding:
                  EdgeInsets.only(right: 8, bottom: footer == null ? 0 : 18),
              child: showAvatar
                  ? UserAvatar(name: senderName, radius: 15)
                  : const SizedBox(width: 30),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group && showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(senderName!,
                        style: inter(12.5,
                            weight: FontWeight.w600, color: palette.muted)),
                  ),
                withLongPress,
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child:
                        Text(footer!, style: inter(12, color: palette.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Edited · 10:42" / "10:42" under a run of messages.
String messageFooter(Message m, {String? prefix}) {
  final time = DateFormat.Hm().format(m.createdAt.toLocal());
  return [
    if (prefix != null) prefix,
    if (m.isEdited) 'Edited',
    time,
  ].join(' · ');
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.isMine,
    required this.body,
    required this.maxWidth,
    this.replyTo,
    this.replySenderName,
  });

  final bool isMine;
  final String body;
  final double maxWidth;
  final Message? replyTo;
  final String? replySenderName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final textColor = isMine ? Colors.white : onSurface;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: BoxDecoration(
          color: isMine ? palette.accent : palette.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6, top: 2),
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.18)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                      left: BorderSide(
                          color: isMine ? Colors.white : palette.accent,
                          width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replySenderName != null)
                      Text(replySenderName!,
                          style: inter(12.5,
                              weight: FontWeight.w600,
                              color: isMine ? Colors.white : palette.accent)),
                    Text(replyTo!.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: inter(13.5,
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.85)
                                : palette.muted)),
                  ],
                ),
              ),
            if (body.isNotEmpty)
              Text(body, style: inter(15.5, color: textColor, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _DeletedPill extends StatelessWidget {
  const _DeletedPill({required this.text, this.icon = Icons.block_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: palette.muted),
          const SizedBox(width: 6),
          Text(text, style: inter(14.5, color: palette.muted)),
        ],
      ),
    );
  }
}

/// A message whose photos or files are still uploading, with the percentage,
/// or that failed, with Retry and Remove.
class OutgoingBubble extends StatelessWidget {
  const OutgoingBubble({
    required this.outgoing,
    required this.onRetry,
    required this.onRemove,
    super.key,
  });

  final OutgoingMessage outgoing;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final failed = outgoing.failed;
    final images = outgoing.files.where((f) => f.isImage).toList();
    final others = outgoing.files.where((f) => !f.isImage).toList();
    final value = failed ? null : outgoing.progress.clamp(0.02, 1.0).toDouble();

    Widget ring({double size = 34, Color color = Colors.white}) =>
        SizedBox.square(
          dimension: size,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.3),
          ),
        );

    Widget overlay() => failed
        ? Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle),
            child: Icon(Icons.refresh_rounded, color: palette.accent),
          )
        : Stack(
            alignment: Alignment.center,
            children: [
              ring(),
              Text('${outgoing.percent}%',
                  style: inter(10.5,
                      weight: FontWeight.w600, color: Colors.white)),
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (images.isNotEmpty)
            GestureDetector(
              onTap: failed ? onRetry : null,
              child: SizedBox(
                width: kChatMediaWidth,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final f in images)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.memory(f.bytes,
                                width: images.length == 1
                                    ? kChatMediaWidth
                                    : (kChatMediaWidth - 4) / 2,
                                height: images.length == 1 ? 200 : 118,
                                fit: BoxFit.cover),
                            Positioned.fill(
                                child: ColoredBox(
                                    color:
                                        Colors.black.withValues(alpha: 0.35))),
                            overlay(),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          for (final f in others)
            Container(
              width: kChatMediaWidth,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: failed ? palette.surface2 : palette.accent,
                  borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                        f.type == 'video'
                            ? Icons.videocam_rounded
                            : Icons.description_rounded,
                        color: palette.verified),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: inter(14.5,
                                weight: FontWeight.w500,
                                color: failed
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.white)),
                        Text(
                            failed
                                ? 'Not sent'
                                : 'Sending… ${outgoing.percent}%',
                            style: inter(12.5,
                                color: failed
                                    ? palette.accent
                                    : Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  if (!failed) ...[
                    const SizedBox(width: 8),
                    ring(size: 20),
                  ],
                ],
              ),
            ),
          if (outgoing.body != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Opacity(
                opacity: failed ? 0.6 : 1,
                child: _TextBubble(
                  isMine: true,
                  body: outgoing.body!,
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: failed
                ? _FailedLine(
                    error: outgoing.error!,
                    onRetry: onRetry,
                    onRemove: onRemove)
                : Text('Sending… ${outgoing.percent}%',
                    style: inter(12, color: palette.muted)),
          ),
        ],
      ),
    );
  }
}

class _FailedLine extends StatelessWidget {
  const _FailedLine(
      {required this.error, required this.onRetry, required this.onRemove});

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget link(String label, VoidCallback onTap, Color color) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(label,
                style: inter(13, weight: FontWeight.w600, color: color)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 15, color: palette.accent),
            const SizedBox(width: 4),
            Text('Not sent', style: inter(12.5, color: palette.accent)),
            const SizedBox(width: 6),
            link('Retry', onRetry, palette.accent),
            link('Remove', onRemove, onSurface),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kChatMediaWidth),
          child: Text(error,
              textAlign: TextAlign.right,
              style: inter(12, color: palette.muted)),
        ),
      ],
    );
  }
}

/// "Today", "Yesterday" or a date, between days in the thread.
class DayChip extends StatelessWidget {
  const DayChip({required this.day, super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final d = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat(d.year == now.year ? 'EEE d MMM' : 'd MMM yyyy')
                .format(d);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: palette.surface2, borderRadius: BorderRadius.circular(12)),
          child: Text(label,
              style: inter(12, weight: FontWeight.w500, color: palette.muted)),
        ),
      ),
    );
  }
}

/// Swipe a message to the right to reply. The message follows the finger, a
/// reply arrow fades in on its left and turns red (with a light tap) once the
/// swipe is far enough; letting go there calls [onReply]. Swipes that start at
/// the screen's left edge are left alone for the system back gesture.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({required this.child, required this.onReply, super.key});

  final Widget child;
  final VoidCallback onReply;

  /// How far to swipe before letting go replies.
  static const double trigger = 64;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxPull = 88;
  static const double _edge = 24;

  late final AnimationController _back = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180))
    ..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _dx = 0;
  double _from = 0;
  bool _active = false;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _start(DragStartDetails d) {
    _active = d.globalPosition.dx > _edge;
    _armed = false;
    _back.stop();
  }

  void _update(DragUpdateDetails d) {
    if (!_active) return;
    final next = (_dx + d.delta.dx).clamp(0.0, _maxPull);
    final armed = next >= SwipeToReply.trigger;
    if (armed && !_armed) HapticFeedback.lightImpact();
    setState(() {
      _dx = next;
      _armed = armed;
    });
  }

  void _end([DragEndDetails? _]) {
    if (!_active) return;
    _active = false;
    if (_armed) widget.onReply();
    _armed = false;
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = (_dx / SwipeToReply.trigger).clamp(0.0, 1.0);
    return Semantics(
      identifier: 'swipe-message',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        onHorizontalDragCancel: _end,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (_dx > 0)
              Positioned(
                left: 2,
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * progress,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _armed ? palette.accent : palette.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.reply_rounded,
                          size: 18,
                          color: _armed ? Colors.white : palette.muted),
                    ),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(_dx, 0), child: widget.child),
          ],
        ),
      ),
    );
  }
}

/// Several messages in a row that can't be read on this phone, shown as one
/// small pill: "24 locked messages" before a restore, "3 messages can't be
/// read on this phone" after.
class LockedRunPill extends StatelessWidget {
  const LockedRunPill(
      {required this.count,
      required this.beforeRestore,
      this.onLongPress,
      super.key});

  final int count;
  final bool beforeRestore;
  final VoidCallback? onLongPress;

  static String label(int count, {required bool beforeRestore}) {
    final one = count == 1;
    if (beforeRestore) {
      return one ? '1 locked message' : '$count locked messages';
    }
    return one
        ? '1 message can’t be read on this phone'
        : '$count messages can’t be read on this phone';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 15, color: palette.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label(count, beforeRestore: beforeRestore),
                      style: inter(13, color: palette.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floats over a reversed thread: "↓ Latest" once the reader has scrolled
/// more than a screen up, "↓ N new messages" in accent when others write
/// meanwhile. Tapping it scrolls back to the newest message.
class JumpToLatest extends StatefulWidget {
  const JumpToLatest(
      {required this.controller,
      required this.newestKey,
      required this.newestFromOthers,
      super.key});

  final ScrollController controller;

  /// Identifies the newest message; a change means one arrived.
  final Object? newestKey;
  final bool newestFromOthers;

  static String label(int unseen) => switch (unseen) {
        0 => 'Latest',
        1 => '1 new message',
        _ => '$unseen new messages',
      };

  /// Back to the newest message. A long way up jumps most of it at once so
  /// the animation never runs through pages of history.
  static Future<void> scrollToLatest(ScrollController controller) async {
    if (!controller.hasClients) return;
    final position = controller.position;
    final screen = position.viewportDimension;
    if (position.pixels > screen * 5) controller.jumpTo(screen);
    await controller.animateTo(0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  @override
  State<JumpToLatest> createState() => _JumpToLatestState();
}

class _JumpToLatestState extends State<JumpToLatest> {
  bool _away = false;
  int _unseen = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(JumpToLatest old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (_away &&
        widget.newestFromOthers &&
        widget.newestKey != null &&
        widget.newestKey != old.newestKey) {
      _unseen++;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final position = widget.controller.position;
    // Reversed list: 0 is the newest end.
    final away = position.pixels > position.viewportDimension;
    if (away == _away) return;
    setState(() {
      _away = away;
      if (!away) _unseen = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final alert = _unseen > 0;
    final text = alert ? Colors.white : theme.colorScheme.onSurface;
    return IgnorePointer(
      ignoring: !_away,
      child: AnimatedSlide(
        offset: _away ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _away ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Semantics(
            identifier: 'jump-latest',
            button: true,
            child: GestureDetector(
              onTap: () => JumpToLatest.scrollToLatest(widget.controller),
              child: Container(
                height: 34,
                padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
                decoration: BoxDecoration(
                  color: alert
                      ? palette.accent
                      : dark
                          ? palette.surface2
                          : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: alert
                      ? null
                      : Border.all(
                          color: dark
                              ? palette.muted.withValues(alpha: 0.5)
                              : palette.border),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        size: 18, color: alert ? Colors.white : palette.accent),
                    const SizedBox(width: 6),
                    Text(JumpToLatest.label(_unseen),
                        style: inter(14, weight: FontWeight.w500, color: text)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
