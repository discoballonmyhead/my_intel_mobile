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
    this.onVote,
    this.highlight = false,
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

  /// Casts a poll vote; returns whether it went through.
  final Future<bool> Function(int optionId)? onVote;

  /// Briefly tints the post, e.g. right after "new posts" are revealed.
  final bool highlight;

  /// News posts carry the NEWS badge for this long, as on the web app.
  static const Duration newsBadgeWindow = Duration(hours: 48);

  static const double _avatarRadius = 20;
  static const double _textInset = _avatarRadius * 2 + 12;

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
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: palette.border.withValues(alpha: 0.6))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item case RepostedPost(:final reposter)) ...[
                Padding(
                  padding: const EdgeInsets.only(left: _textInset),
                  child: Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 14, color: palette.muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${reposter?.username ?? 'Someone'} reposted',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                      ),
                    ],
                  ),
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
          ),
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

    return SizedBox(
      height: 26,
      child: Row(
        children: [
          // Name, role icon and NEWS badge take the left; time and ⋯ stay
          // pinned to the right edge whatever the name's length.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: author == null
                        ? null
                        : () => onAuthorTap?.call(author.username),
                    child: Text(
                      author?.username ?? 'unknown',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (author != null) ...[
                  const SizedBox(width: 5),
                  RoleBadge(role: author.role, compact: true),
                ],
                if (isNews) ...[
                  const SizedBox(width: 7),
                  const _NewsBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(post.isEdited ? '${post.createdAt.timeAgo} · edited' : post.createdAt.timeAgo,
              style: muted),
          if (onMore != null)
            SizedBox(
              width: 34,
              height: 26,
              child: IconButton(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz_rounded,
                    size: 20, color: palette.muted),
                onPressed: onMore,
              ),
            ),
        ],
      ),
    );
  }
}

class _NewsBadge extends StatelessWidget {
  const _NewsBadge();

  @override
  Widget build(BuildContext context) {
    final green = context.palette.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('NEWS',
          style: AppTypography.mono(
              size: 8, weight: FontWeight.w700, color: green, letterSpacing: 1)),
    );
  }
}

class _PostImage extends StatelessWidget {
  const _PostImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: palette.surface2),
            errorWidget: (_, __, ___) => Container(
              color: palette.surface2,
              child: Icon(Icons.broken_image_outlined, color: palette.muted),
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
    this.onShare,
    this.onReply,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Transform.translate(
      offset: const Offset(-10, 0),
      child: Row(
        children: [
          _ActionButton(
            icon: post.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            count: post.likes,
            active: post.liked,
            activeColor: palette.accent2,
            tooltip: post.liked ? 'Unlike' : 'Like',
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            count: post.replyCount,
            tooltip: 'Replies',
            onTap: onReply,
          ),
          _ActionButton(
            icon: Icons.repeat_rounded,
            count: post.repostCount,
            active: post.reposted,
            activeColor: palette.verified,
            tooltip: post.reposted ? 'Undo repost' : 'Repost',
            onTap: onRepost,
          ),
          const Spacer(),
          Transform.translate(
            offset: const Offset(20, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Share',
                  onTap: onShare,
                ),
                _ActionButton(
                  icon: post.saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  active: post.saved,
                  activeColor: palette.accent,
                  tooltip: post.saved ? 'Unsave' : 'Save',
                  onTap: onSave,
                ),
              ],
            ),
          ),
        ],
      ),
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
