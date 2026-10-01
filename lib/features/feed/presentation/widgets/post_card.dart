import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    required this.item,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onTap,
    this.onAuthorTap,
    this.onMore,
    this.onComment,
    super.key,
  });

  final FeedItem item;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onTap;
  final ValueChanged<String>? onAuthorTap;

  /// Opens the ⋯ menu (edit, delete, report, moderate).
  final VoidCallback? onMore;

  /// Opens the comments (post detail) screen.
  final VoidCallback? onComment;

  Post get post => item.post;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item case RepostedPost(:final reposter)) ...[
              Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 12, color: palette.muted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${reposter?.username ?? 'someone'} reposted',
                    style: AppTypography.mono(size: 9, color: palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _Header(
              post: post,
              item: item,
              onAuthorTap: onAuthorTap,
              onMore: onMore,
            ),
            if (post.isUnderReview || post.isRemoved) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                post.isRemoved
                    ? 'REMOVED BY MODERATORS · ONLY YOU CAN SEE THIS'
                    : 'UNDER REVIEW',
                style: AppTypography.mono(
                  size: 9,
                  color: post.isRemoved ? palette.accent2 : palette.warn,
                ),
              ),
            ],
            if (item case RepostedPost(:final quote) when quote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(quote, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(post.body, style: theme.textTheme.bodyMedium),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(post.body, style: theme.textTheme.bodyMedium),
            ],
            if (post.hasMedia) ...[
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: palette.surface2,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: palette.surface2,
                    child: Icon(Icons.broken_image_outlined, color: palette.muted),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _ActionBar(
              post: post,
              onLike: onLike,
              onSave: onSave,
              onRepost: onRepost,
              onComment: onComment ?? onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.item,
    this.onAuthorTap,
    this.onMore,
  });

  final Post post;
  final FeedItem item;
  final ValueChanged<String>? onAuthorTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = post.author;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: author == null ? null : () => onAuthorTap?.call(author.username),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: palette.surface2,
            child: Text(
              (author?.username ?? '?').characters.first.toUpperCase(),
              style: AppTypography.mono(size: 12, color: palette.accent),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author?.username ?? 'unknown',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (author != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    RoleBadge(role: author.role, compact: true),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    post.isEdited
                        ? '${post.createdAt.timeAgo} · edited'
                        : post.createdAt.timeAgo,
                    style: AppTypography.mono(size: 9, color: palette.muted),
                  ),
                ],
              ),
              if (author != null && author.isAnalyst)
                Text(
                  'CRED ${author.score}',
                  style: AppTypography.mono(size: 9, color: palette.muted),
                ),
            ],
          ),
        ),
        if (post.tag != null) TagChip(label: post.tag!),
        if (onMore != null)
          IconButton(
            tooltip: 'More',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.more_horiz_rounded, size: 18, color: palette.muted),
            onPressed: onMore,
          ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.post,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onComment,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        _ActionButton(
          icon: post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: post.likes,
          active: post.liked,
          activeColor: palette.accent2,
          onTap: onLike,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: post.replyCount,
          onTap: onComment,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          icon: Icons.repeat_rounded,
          label: post.repostCount,
          active: post.reposted,
          activeColor: palette.verified,
          onTap: onRepost,
        ),
        const Spacer(),
        _ActionButton(
          icon: post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          active: post.saved,
          activeColor: palette.accent,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final int? label;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? (activeColor ?? palette.accent) : palette.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label != null && label! > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Text('$label', style: AppTypography.mono(size: 10, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
