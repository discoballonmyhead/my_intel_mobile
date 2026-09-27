import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message.dart';

/// Text field + send button, with a banner when replying or editing.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.onSubmit,
    required this.isSending,
    this.replyTo,
    this.replySenderName,
    this.editing,
    this.onCancelReply,
    this.onCancelEdit,
    this.enabled = true,
    this.disabledHint,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isSending;
  final Message? replyTo;
  final String? replySenderName;
  final Message? editing;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCancelEdit;
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget? banner;
    if (editing != null) {
      banner = _Banner(
        icon: Icons.edit_outlined,
        title: 'Editing message',
        body: editing!.preview,
        onClose: onCancelEdit,
      );
    } else if (replyTo != null) {
      banner = _Banner(
        icon: Icons.reply_rounded,
        title: 'Replying to ${replySenderName ?? 'message'}',
        body: replyTo!.preview,
        onClose: onCancelReply,
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (banner != null) banner,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: MessagingPolicy.maxBodyLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: enabled
                            ? 'Message'
                            : disabledHint ?? 'You cannot reply here',
                        counterText: '',
                        isDense: true,
                      ),
                      onSubmitted: (_) => onSubmit(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final canSend = enabled &&
                          !isSending &&
                          value.text.trim().isNotEmpty;
                      return IconButton.filled(
                        onPressed: canSend ? onSubmit : null,
                        icon: isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(editing != null
                                ? Icons.check_rounded
                                : Icons.send_rounded),
                      );
                    },
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.mono(size: 9, color: palette.accent)),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
