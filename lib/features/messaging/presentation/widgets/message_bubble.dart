import 'package:flutter/material.dart';
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
              padding: EdgeInsets.only(right: 8, bottom: footer == null ? 0 : 18),
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
                    child: Text(footer!,
                        style: inter(12, color: palette.muted)),
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
  const _DeletedPill({required this.text});

  final String text;

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
          Icon(Icons.block_rounded, size: 17, color: palette.muted),
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

    Widget ring({double size = 34, Color color = Colors.white}) => SizedBox.square(
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
