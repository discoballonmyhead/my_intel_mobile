import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/post.dart';
import 'photo_viewer.dart';
import 'post_attachments.dart';
import 'post_poll_view.dart';

/// One post in the feed, "clean & airy": round avatar, bold name with role
/// icon and time on the right, plain text, rounded photo, a soft
/// `📍 region · #tag` line and roomy actions. No boxes, just soft dividers.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.item,
    this.highlight = false,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onQuote,
    this.myUserId,
    this.onShare,
    this.onTap,
    this.onAuthorTap,
    this.onMore,
    this.onComment,
    this.onVote,
    this.footer,
    super.key,
  });

  /// News posts carry a NEWS mark for this long after they are posted.
  static const Duration newsBadgeWindow = Duration(hours: 24);

  final FeedItem item;

  /// Briefly tints the card, for posts that just arrived at the top.
  final bool highlight;
  final VoidCallback? onLike;
  final VoidCallback? onSave;

  /// Reposts straight away, or undoes your repost.
  final VoidCallback? onRepost;

  /// Opens "Repost with a comment". When set, tapping 🔁 shows a small menu
  /// (Repost / Repost with a comment, or Undo repost) instead of acting at once.
  final VoidCallback? onQuote;

  /// The signed-in user, so their own reposts read "You reposted".
  final String? myUserId;

  /// Copies or shares a link to the post.
  final VoidCallback? onShare;
  final VoidCallback? onTap;
  final ValueChanged<String>? onAuthorTap;

  /// Opens the ⋯ menu (edit, delete, report, moderate).
  final VoidCallback? onMore;

  /// Opens the comments (post detail) screen.
  final VoidCallback? onComment;

  /// Casts a vote in the post's poll; resolves to false when it failed.
  final Future<bool> Function(int optionId)? onVote;

  /// Extra row under the actions (the reaction bar on OSINT posts).
  /// A slot rather than a dependency, so the feed doesn't import reactions.
  final Widget? footer;

  Post get post => item.post;

  static TextStyle _bodyStyle(Color onSurface) =>
      TextStyle(fontSize: 15.5, height: 1.45, color: onSurface);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final repost = item is RepostedPost ? item as RepostedPost : null;
    final content = switch (repost) {
      null => _original(context, palette, onSurface),
      _ when repost.hasQuote =>
        _withComment(context, repost, palette, onSurface),
      _ => _repost(context, repost, palette, onSurface),
    };

    return InkWell(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: highlight ? 1 : 0, end: 0),
        duration: const Duration(milliseconds: 2500),
        curve: Curves.easeOut,
        builder: (context, t, child) => DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
                Colors.transparent, palette.accent.withValues(alpha: 0.08), t),
            border: Border(
                bottom: BorderSide(
                    color: palette.border.withValues(alpha: 0.6))),
          ),
          child: child,
        ),
        child: content,
      ),
    );
  }

  /// A post as its author wrote it.
  Widget _original(BuildContext context, AppPalette palette, Color onSurface,
      {double top = 14}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(profile: post.author, onAuthorTap: onAuthorTap),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  author: post.author,
                  time: post.createdAt,
                  edited: post.isEdited,
                  isNews: _isFreshNews,
                  onAuthorTap: onAuthorTap,
                  onMore: onMore,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _postBody(context, palette, onSurface),
                ),
                _ActionBar(
                  post: post,
                  onLike: onLike,
                  onSave: onSave,
                  onRepost: onRepost,
                  onQuote: onQuote,
                  onShare: onShare,
                  onComment: onComment ?? onTap,
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: footer!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A plain repost: a small "🔁 name reposted" line above the original.
  Widget _repost(BuildContext context, RepostedPost repost, AppPalette palette,
      Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RepostedBy(
          label: _repostLabel(repost),
          reposter: repost.reposter,
          onAuthorTap: onAuthorTap,
        ),
        _original(context, palette, onSurface, top: 4),
      ],
    );
  }

  /// A repost with a comment: the reposter's words, the original post in a
  /// soft card under them, and the actions for the original.
  Widget _withComment(BuildContext context, RepostedPost repost,
      AppPalette palette, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(profile: repost.reposter, onAuthorTap: onAuthorTap),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  author: repost.reposter,
                  time: repost.repostedAt,
                  onAuthorTap: onAuthorTap,
                  onMore: onMore,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(repost.quote!.trim(), style: _bodyStyle(onSurface)),
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: palette.border.withValues(alpha: 0.8)),
                        ),
                        child: QuotedPostPreview(post: post, onTap: onTap),
                      ),
                    ],
                  ),
                ),
                _ActionBar(
                  post: post,
                  onLike: onLike,
                  onSave: onSave,
                  onRepost: onRepost,
                  onQuote: onQuote,
                  onShare: onShare,
                  onComment: onComment ?? onTap,
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: footer!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isFreshNews =>
      post.postType == 'news' &&
      DateTime.now().toUtc().difference(post.createdAt.toUtc()) <
          newsBadgeWindow;

  String _repostLabel(RepostedPost repost) {
    final reposter = repost.reposter;
    if (reposter != null && myUserId != null && reposter.id == myUserId) {
      return 'You reposted';
    }
    return '${reposter?.username ?? 'Someone'} reposted';
  }

  /// Review notes, text, photos / files / poll and the region · tag line.
  Widget _postBody(BuildContext context, AppPalette palette, Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.isPendingReview || post.isUnderReview || post.isRemoved) ...[
          const SizedBox(height: 6),
          _ReviewNote(post: post),
        ],
        if (post.body.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(post.body, style: _bodyStyle(onSurface)),
        ],
        if (post.hasAttachments) ...[
          const SizedBox(height: 10),
          PostAttachments(attachments: post.attachments),
        ] else if (post.hasMedia) ...[
          const SizedBox(height: 10),
          _PostImage(url: post.mediaUrl!),
        ],
        if (post.poll != null) ...[
          const SizedBox(height: 10),
          PostPollView(
            key: ValueKey('poll-${post.id}'),
            poll: post.poll!,
            onVote: onVote,
          ),
        ],
        _MetaLine(post: post),
      ],
    );
  }
}

/// The round avatar on the left of a post; opens the author's channel.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, this.onAuthorTap});

  final Profile? profile;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return GestureDetector(
      onTap: p == null || onAuthorTap == null
          ? null
          : () => onAuthorTap!(p.username),
      child: UserAvatar(name: p?.username, radius: 20),
    );
  }
}

/// "🔁 name reposted", lined up with the post's text.
class _RepostedBy extends StatelessWidget {
  const _RepostedBy({required this.label, this.reposter, this.onAuthorTap});

  final String label;
  final Profile? reposter;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = reposter;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: r == null || onAuthorTap == null
          ? null
          : () => onAuthorTap!(r.username),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 10, 16, 0),
        child: Row(
          children: [
            Icon(Icons.repeat_rounded, size: 15, color: palette.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to the author (and staff) on posts others can't see yet, or at all.
class _ReviewNote extends StatelessWidget {
  const _ReviewNote({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (icon, color, text) = post.isRemoved
        ? (
            Icons.block_rounded,
            palette.accent2,
            'Removed by moderators · only you can see this'
          )
        : post.isPendingReview
            ? (
                Icons.hourglass_top_rounded,
                palette.warn,
                'Waiting for review · only you can see this until a '
                    'moderator approves it'
              )
            : (
                Icons.visibility_outlined,
                palette.warn,
                'Under review'
              );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5, height: 1.35, color: color)),
          ),
        ],
      ),
    );
  }
}

/// A post's single photo from `media_url` (posts made before attachments),
/// at its own shape. Tapping opens it full screen.
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
        child: AdaptivePhoto(
          url: url,
          child: GestureDetector(
            onTap: () => PhotoViewer.open(context, [url]),
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
      ),
    );
  }
}

/// The original post inside a repost with a comment (and in the comment
/// screen): small avatar, name · date, up to three lines and its photo.
class QuotedPostPreview extends StatelessWidget {
  const QuotedPostPreview({required this.post, this.onTap, super.key});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final firstPhoto = post.attachments
        .where(attachmentShowsAsImage)
        .map((a) => a.url)
        .firstOrNull;
    final photo = firstPhoto ?? (post.hasMedia ? post.mediaUrl : null);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(name: post.author?.username, radius: 12),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(post.author?.username ?? 'unknown',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Text(' · ${post.createdAt.timeAgo}',
                      style: TextStyle(fontSize: 13, color: palette.muted)),
                ],
              ),
              if (post.body.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15, height: 1.4, color: onSurface)),
              ],
              if (photo != null) ...[
                const SizedBox(height: 10),
                _PostImage(url: photo),
              ],
              if (post.poll != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.poll_outlined, size: 15, color: palette.muted),
                    const SizedBox(width: 6),
                    Text('Poll · ${post.poll!.totalVotes} votes',
                        style: TextStyle(fontSize: 13, color: palette.muted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _RepostChoice { repost, quote, undo }

/// Small menu under the 🔁 button: Repost / Repost with a comment, or Undo
/// repost for something you already reposted.
Future<void> _showRepostMenu(BuildContext buttonContext, Post post,
    VoidCallback onRepost, VoidCallback onQuote) async {
  final palette = buttonContext.palette;
  final onSurface = Theme.of(buttonContext).colorScheme.onSurface;
  final box = buttonContext.findRenderObject()! as RenderBox;
  final overlay =
      Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
  final topLeft =
      box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
  // A fixed-width menu just under the button, kept inside the screen.
  const menuWidth = 244.0;
  final left = (topLeft.dx - 8).clamp(8.0, overlay.size.width - menuWidth - 8);
  final position = RelativeRect.fromLTRB(left, topLeft.dy,
      overlay.size.width - left - menuWidth, overlay.size.height - topLeft.dy);
  PopupMenuItem<_RepostChoice> item(
          _RepostChoice value, IconData icon, Color iconColor, String label,
          [Color? labelColor]) =>
      PopupMenuItem(
        value: value,
        height: 50,
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? onSurface)),
          ],
        ),
      );

  final choice = await showMenu<_RepostChoice>(
    context: buttonContext,
    position: position,
    constraints: const BoxConstraints.tightFor(width: menuWidth),
    color: Theme.of(buttonContext).colorScheme.surface,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    items: post.reposted
        ? [
            item(_RepostChoice.undo, Icons.repeat_rounded, palette.accent,
                'Undo repost', palette.accent)
          ]
        : [
            item(_RepostChoice.repost, Icons.repeat_rounded, palette.verified,
                'Repost'),
            item(_RepostChoice.quote, Icons.edit_note_rounded, onSurface,
                'Repost with a comment'),
          ],
  );
  switch (choice) {
    case _RepostChoice.repost || _RepostChoice.undo:
      onRepost();
    case _RepostChoice.quote:
      onQuote();
    case null:
      break;
  }
}

/// Bold name, role icon, NEWS mark and time; the ⋯ menu on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.author,
    required this.time,
    this.edited = false,
    this.isNews = false,
    this.onAuthorTap,
    this.onMore,
  });

  final Profile? author;
  final DateTime time;
  final bool edited;
  final bool isNews;
  final ValueChanged<String>? onAuthorTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final a = author;
    final muted = TextStyle(fontSize: 13, color: palette.muted);

    // The name opens the profile too, not just the avatar; otherwise tapping
    // it falls through to the card's tap (post detail).
    final openProfile = a == null || onAuthorTap == null
        ? null
        : () => onAuthorTap!(a.username);

    final newsMark = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('NEWS',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: palette.accent)),
    );

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openProfile,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      a?.username ?? 'unknown',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (a != null) ...[
                    const SizedBox(width: 4),
                    RoleBadge(role: a.role, compact: true),
                  ],
                  if (a != null && a.isAnalyst) ...[
                    const SizedBox(width: 6),
                    Text('${a.score}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.muted)),
                  ],
                  if (isNews) ...[const SizedBox(width: 6), newsMark],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(edited ? '${time.timeAgo} · edited' : time.timeAgo,
              style: muted),
          if (onMore != null)
            IconButton(
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
              icon:
                  Icon(Icons.more_horiz_rounded, size: 20, color: palette.muted),
              onPressed: onMore,
            )
          else
            const SizedBox(width: 8),
        ],
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
              child:
                  Text(region, overflow: TextOverflow.ellipsis, style: style),
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
    this.onQuote,
    this.onShare,
    this.onComment,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onQuote;
  final VoidCallback? onShare;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            tooltip: 'Comment',
            count: post.replyCount,
            onTap: onComment,
          ),
          Builder(
            builder: (buttonContext) => _ActionButton(
              icon: Icons.repeat_rounded,
              tooltip: post.reposted ? 'Undo repost' : 'Repost',
              count: post.repostCount,
              active: post.reposted,
              activeColor: palette.verified,
              onTap: onRepost == null
                  ? null
                  : onQuote == null
                      ? onRepost
                      : () => _showRepostMenu(
                          buttonContext, post, onRepost!, onQuote!),
            ),
          ),
          _ActionButton(
            icon: post.liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            tooltip: post.liked ? 'Unlike' : 'Like',
            count: post.likes,
            active: post.liked,
            activeColor: palette.accent2,
            onTap: onLike,
          ),
          _ActionButton(
            icon: post.saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            tooltip: post.saved ? 'Remove from saved' : 'Save',
            active: post.saved,
            activeColor: palette.accent,
            onTap: onSave,
            minWidth: 44,
          ),
          if (onShare != null)
            _ActionButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'Share',
              onTap: onShare,
              minWidth: 44,
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
    this.minWidth = 60,
  });

  final double minWidth;
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
          constraints: BoxConstraints(minWidth: minWidth, minHeight: 44),
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
