import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/comment.dart';

class CommentComposer extends StatelessWidget {
  const CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.isSending,
    this.replyTo,
    this.editing,
    this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isSending;
  final Comment? replyTo;
  final Comment? editing;

  /// Cancels the reply / edit banner.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final banner = editing != null
        ? 'Editing your comment'
        : replyTo != null
            ? 'Replying to @${replyTo!.author?.username ?? 'comment'}'
            : null;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (banner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xs, AppSpacing.xs, 0),
                child: Row(
                  children: [
                    Icon(editing != null ? Icons.edit_outlined : Icons.reply_rounded,
                        size: 14, color: palette.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(banner,
                          style: AppTypography.mono(size: 9, color: palette.accent)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: onCancel,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: CommentPolicy.maxLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: replyTo != null ? 'Write a reply' : 'Add a comment',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => IconButton.filled(
                      onPressed: !isSending && value.text.trim().isNotEmpty
                          ? onSubmit
                          : null,
                      icon: isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(editing != null
                              ? Icons.check_rounded
                              : Icons.send_rounded),
                    ),
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
