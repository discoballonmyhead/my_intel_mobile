import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/post.dart';

enum PostAction { edit, delete, history, report, modRemove, viewAuthor }

/// The ⋯ menu on a post. Only offers what the viewer is allowed to do; the
/// RPCs enforce the same rules server-side.
class PostActionsSheet extends StatelessWidget {
  const PostActionsSheet._({
    required this.post,
    required this.isOwner,
    required this.isStaff,
  });

  final Post post;
  final bool isOwner;
  final bool isStaff;

  static Future<PostAction?> show(
    BuildContext context, {
    required Post post,
    required String? myUserId,
    required bool isStaff,
  }) {
    return showModalBottomSheet<PostAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => PostActionsSheet._(
        post: post,
        isOwner: post.isOwnedBy(myUserId),
        isStaff: isStaff,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    void pick(PostAction a) => Navigator.of(context).pop(a);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner && !post.isRemoved)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit post'),
              onTap: () => pick(PostAction.edit),
            ),
          if (post.isEdited && (isOwner || isStaff))
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Edit history'),
              onTap: () => pick(PostAction.history),
            ),
          if (isOwner)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: palette.accent2),
              title: const Text('Delete post'),
              onTap: () => pick(PostAction.delete),
            ),
          if (!isOwner && post.author != null)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text('View @${post.author!.username}'),
              onTap: () => pick(PostAction.viewAuthor),
            ),
          if (!isOwner)
            ListTile(
              leading: Icon(Icons.flag_outlined, color: palette.warn),
              title: const Text('Report post'),
              onTap: () => pick(PostAction.report),
            ),
          if (isStaff && !isOwner && !post.isRemoved)
            ListTile(
              leading: Icon(Icons.gavel_outlined, color: palette.accent2),
              title: const Text('Remove post (moderator)'),
              onTap: () => pick(PostAction.modRemove),
            ),
        ],
      ),
    );
  }
}
