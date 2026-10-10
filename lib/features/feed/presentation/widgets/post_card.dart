import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/post.dart';
import 'post_attachments.dart';
import 'post_poll_view.dart';

/// One post in the feed, "clean & airy": round avatar, bold name with role
/// icon and time on the right, plain text, rounded photo, a soft
/// `📍 region · #tag` line and roomy actions. No boxes, just soft dividers.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.item,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onShare,
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

  /// Copies or shares a link to the post.
  final VoidCallback? onShare;
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
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: highlight ? 1 : 0, end: 0),
        duration: const Duration(milliseconds: 2500),
        curve: Curves.easeOut,
        builder: (context, t, child) => Container(
          color: Color.lerp(
              Colors.transparent, palette.accent.withValues(alpha: 0.08), t),
          child: child,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item case RepostedPost(:final reposter)) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: reposter == null
                    ? null
                    : () => onAuthorTap?.call(reposter.username),
                child: Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 12, color: palette.muted),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${reposter?.username ?? 'someone'} reposted',
                      style: AppTypography.mono(size: 9, color: palette.muted),
                    ),
                  ],
                ),
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
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: post.author == null
                        ? null
                        : () => onAuthorTap?.call(post.author!.username),
                    child: UserAvatar(
                        name: post.author?.username, radius: _avatarRadius),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(post: post, onAuthorTap: onAuthorTap, onMore: onMore),
                        if (post.isUnderReview ||
                            post.isPendingReview ||
                            post.isRemoved) ...[
                          const SizedBox(height: 4),
                          Text(
                            post.isRemoved
                                ? 'Removed by moderators · only you can see this'
                                : post.isPendingReview
                                    ? 'Waiting for review · only you can see this'
                                    : 'Under review',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: post.isRemoved ? palette.accent2 : palette.warn,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        if (item case RepostedPost(:final quote)
                            when quote != null) ...[
                          Text(quote, style: _bodyStyle(onSurface)),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              border: Border.all(color: palette.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(post.body, style: _bodyStyle(onSurface)),
                          ),
                        ] else
                          Text(post.body, style: _bodyStyle(onSurface)),
                        // media_url only mirrors the first photo when a post
                        // has attachments, so it is the fallback, not both.
                        if (post.hasAttachments) ...[
                          const SizedBox(height: 10),
                          PostAttachments(attachments: post.attachments),
                        ] else if (post.hasMedia) ...[
                          const SizedBox(height: 10),
                          _PostImage(url: post.mediaUrl!),
                        ],
                        if (post.poll case final poll?) ...[
                          const SizedBox(height: 10),
                          PostPollView(poll: poll, onVote: onVote),
                        ],
                        _MetaLine(post: post),
                        const SizedBox(height: 2),
                        _ActionBar(
                          post: post,
                          onLike: onLike,
                          onSave: onSave,
                          onRepost: onRepost,
                          onShare: onShare,
                          onReply: onTap,
                        ),
                      ],
                    ),
                  ),
                ],
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

  static TextStyle _bodyStyle(Color color) =>
      TextStyle(fontSize: 15, height: 1.45, color: color);
}

class _Header extends StatelessWidget {
  const _Header({required this.post, this.onAuthorTap, this.onMore});

  final Post post;
  final ValueChanged<String>? onAuthorTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = post.author;
    final isNews = post.postType == 'news' &&
        DateTime.now().toUtc().difference(post.createdAt.toUtc()) <
            PostCard.newsBadgeWindow;
    final muted = TextStyle(fontSize: 13, color: palette.muted);

    // Avatar AND name open the profile. Previously only the 32px avatar did,
    // so tapping the username fell through to the card's tap (post detail).
    final openProfile = author == null || onAuthorTap == null
        ? null
        : () => onAuthorTap!.call(author.username);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: openProfile,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: palette.surface2,
                  child: Text(
                    (author?.username ?? '?').characters.first.toUpperCase(),
                    style: AppTypography.mono(size: 12, color: palette.accent),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `📍 Region · #tag` in plain text, showing only the parts a post has.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tag = post.tag?.trim() ?? '';
    final region = post.region?.trim() ?? '';
    if (tag.isEmpty && region.isEmpty) return const SizedBox(height: 2);

    final style = TextStyle(fontSize: 12, color: palette.muted);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (region.isNotEmpty) ...[
            Icon(Icons.place_outlined, size: 13, color: palette.muted),
            const SizedBox(width: 3),
            Flexible(
              child: Text(region, overflow: TextOverflow.ellipsis, style: style),
            ),
          ],
          if (region.isNotEmpty && tag.isNotEmpty) Text(' · ', style: style),
          if (tag.isNotEmpty) Text('#${tag.toLowerCase()}', style: style),
        ],
      ),
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
    required this.tooltip,
    this.count,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final int? count;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final idle = Color.lerp(
        Theme.of(context).colorScheme.onSurface, palette.muted, 0.35)!;
    final color = active ? (activeColor ?? palette.accent) : idle;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 60, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text('$count', style: TextStyle(fontSize: 13, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
