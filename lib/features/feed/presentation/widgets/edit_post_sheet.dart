import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';

/// Returns the new body, or null if cancelled.
class EditPostSheet extends StatefulWidget {
  const EditPostSheet._({required this.post});

  final Post post;

  static Future<String?> show(BuildContext context, Post post) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EditPostSheet._(post: post),
    );
  }

  @override
  State<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<EditPostSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.post.body);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit post', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Readers will see that this post was edited. Earlier versions '
            'stay visible to you and to moderators.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 10,
            maxLength: CreatePost.maxLength,
          ),
          const SizedBox(height: AppSpacing.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final text = value.text.trim();
              final changed =
                  text.isNotEmpty && text != widget.post.body.trim();
              return FilledButton(
                onPressed:
                    changed ? () => Navigator.of(context).pop(text) : null,
                child: const Text('SAVE'),
              );
            },
          ),
        ],
      ),
    );
  }
}
