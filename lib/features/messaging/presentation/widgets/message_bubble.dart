import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.replyTo,
    this.replySenderName,
    this.showSeen = false,
    this.onLongPress,
    super.key,
  });

  final Message message;
  final bool isMine;

  /// Shown above other people's messages in groups.
  final String? senderName;
  final Message? replyTo;
  final String? replySenderName;
  final bool showSeen;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            message.preview,
            style: AppTypography.mono(size: 9, color: palette.muted),
          ),
        ),
      );
    }

    final background = isMine ? palette.accent.withValues(alpha: 0.16) : palette.surface2;
    final deleted = message.isDeleted;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: deleted && !isMine ? null : onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: deleted ? Colors.transparent : background,
              border: deleted ? Border.all(color: palette.border) : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSpacing.radiusLg),
                topRight: const Radius.circular(AppSpacing.radiusLg),
                bottomLeft: Radius.circular(isMine ? AppSpacing.radiusLg : 4),
                bottomRight: Radius.circular(isMine ? 4 : AppSpacing.radiusLg),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName != null && !isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      senderName!,
                      style: AppTypography.mono(size: 9, color: palette.accent),
                    ),
                  ),
                if (replyTo != null && !deleted) _ReplyQuote(
                  message: replyTo!,
                  senderName: replySenderName,
                ),
                if (deleted)
                  Text(
                    message.preview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: palette.muted,
                    ),
                  )
                else ...[
                  for (final attachment in message.attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: attachment.isImage
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              child: CachedNetworkImage(
                                imageUrl: attachment.url,
                                width: 220,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 220,
                                  height: 160,
                                  color: palette.surface2,
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: palette.muted,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_file_rounded,
                                    size: 14, color: palette.muted),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    attachment.name ?? 'Attachment',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  if ((message.body ?? '').isNotEmpty)
                    SelectableText(
                      message.body!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurface),
                    ),
                ],
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Text('edited',
                            style: AppTypography.mono(
                                size: 8, color: palette.muted)),
                      ),
                    Text(
                      DateFormat.Hm().format(message.createdAt.toLocal()),
                      style: AppTypography.mono(size: 8, color: palette.muted),
                    ),
                    if (showSeen) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.done_all_rounded,
                          size: 11, color: palette.accent),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.message, this.senderName});

  final Message message;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.accent, width: 2)),
        color: palette.border.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null)
            Text(senderName!,
                style: AppTypography.mono(size: 8, color: palette.accent)),
          Text(
            message.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
