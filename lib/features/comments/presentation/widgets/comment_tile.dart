import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/comment.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    required this.comment,
    this.isReply = false,
    this.isPostAuthor = false,
    this.onReply,
    this.onLike,
    this.onMore,
    this.onAuthorTap,
    super.key,
  });

  final Comment comment;
  final bool isReply;

  /// Shows an "AUTHOR" tag when the commenter wrote the post.
  final bool isPostAuthor;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onMore;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final author = comment.author;
    final gone = comment.isDeleted || (comment.isRemoved && comment.body == null);
    final name = comment.authorId == null
        ? 'deleted user'
        : author?.username ?? 'unknown';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isReply ? AppSpacing.xxxl : AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: author == null ? null : () => onAuthorTap?.call(author.username),
            child: UserAvatar(
              name: gone ? null : name,
              radius: isReply ? 13 : 16,
              icon: gone ? Icons.chat_bubble_outline_rounded : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!gone)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    children: [
                      GestureDetector(
                        onTap: author == null
                            ? null
                            : () => onAuthorTap?.call(author.username),
                        child: Text(name, style: theme.textTheme.titleSmall),
                      ),
                      if (author != null) RoleBadge(role: author.role, compact: true),
                      if (isPostAuthor)
                        Text('AUTHOR',
                            style: AppTypography.mono(size: 8, color: palette.accent)),
                      Text(
                        comment.isEdited
                            ? '${comment.createdAt.timeAgo} · edited'
                            : comment.createdAt.timeAgo,
                        style: AppTypography.mono(size: 9, color: palette.muted),
                      ),
                    ],
                  ),
                if (comment.isRemoved && !comment.isDeleted)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('REMOVED BY MODERATORS',
                        style: AppTypography.mono(size: 8, color: palette.accent2)),
                  ),
                const SizedBox(height: 2),
                if (comment.replyToProfile != null && !gone)
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '@${comment.replyToProfile!.username} ',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: palette.accent),
                      ),
                      TextSpan(
                          text: comment.displayBody,
                          style: theme.textTheme.bodyMedium),
                    ]),
                  )
                else
                  Text(
                    comment.displayBody,
                    style: gone
                        ? theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic, color: palette.muted)
                        : theme.textTheme.bodyMedium,
                  ),
                if (!gone)
                  Row(
                    children: [
                      _SmallAction(
                        icon: comment.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: comment.likeCount > 0 ? '${comment.likeCount}' : null,
                        color: comment.liked ? palette.accent2 : palette.muted,
                        onTap: comment.isRemoved ? null : onLike,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _SmallAction(
                        icon: Icons.reply_rounded,
                        label: 'Reply',
                        color: palette.muted,
                        onTap: comment.isRemoved ? null : onReply,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (onMore != null && !comment.isDeleted)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_horiz_rounded, size: 18, color: palette.muted),
              onPressed: onMore,
            ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(label!, style: AppTypography.mono(size: 9, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
