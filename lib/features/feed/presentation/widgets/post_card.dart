import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/post.dart';

/// One post in the feed, "clean & airy": round avatar, bold name with role
/// icon and time on the right, plain text, rounded photo, a soft
/// `📍 region · #tag` line and roomy actions. No boxes, just soft dividers.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.item,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onQuote,
    this.onShare,
    this.onTap,
    this.onAuthorTap,
    this.onMore,
    this.myUserId,
    this.highlight = false,
    super.key,
  });

  final FeedItem item;
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

  /// Briefly tints the post, e.g. right after "new posts" are revealed.
  final bool highlight;

  /// News posts carry the NEWS badge for this long, as on the web app.
  static const Duration newsBadgeWindow = Duration(hours: 48);

  static const double _avatarRadius = 20;

  Post get post => item.post;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final repost = item is RepostedPost ? item as RepostedPost : null;
    final content = switch (repost) {
      null => _original(context, palette, onSurface),
      _ when repost.hasQuote =>
        _withComment(context, repost, palette, onSurface),
      _ => _repost(context, repost, palette),
    };

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
                bottom:
                    BorderSide(color: palette.border.withValues(alpha: 0.6))),
          ),
          child: content,
        ),
      ),
    );
  }

  /// A normal post: avatar, then name, text, media and actions.
  Widget _original(BuildContext context, AppPalette palette, Color onSurface) =>
      _PostBlock(
        post: post,
        avatarRadius: _avatarRadius,
        onLike: onLike,
        onSave: onSave,
        onRepost: onRepost,
        onQuote: onQuote,
        onShare: onShare,
        onReply: onTap,
        onAuthorTap: onAuthorTap,
        onMore: onMore,
      );

  /// A repost without a comment: "You reposted · 2h", then the original
  /// post in a soft card.
  Widget _repost(
      BuildContext context, RepostedPost repost, AppPalette palette) {
    final mine = myUserId != null && repost.reposter?.id == myUserId;
    final who = mine ? 'You' : (repost.reposter?.username ?? 'Someone');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(name: repost.reposter?.username, radius: 12),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: who,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                      text: ' reposted · ${repost.repostedAt.timeAgo}',
                      style: TextStyle(color: palette.muted)),
                ]),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _PostBlock(
            post: post,
            avatarRadius: 16,
            onLike: onLike,
            onSave: onSave,
            onRepost: onRepost,
            onQuote: onQuote,
            onShare: onShare,
            onReply: onTap,
            onAuthorTap: onAuthorTap,
            onMore: onMore,
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /// A repost with a comment reads as the reposter's own post: their
  /// comment, then the original in a soft card, then its actions.
  Widget _withComment(BuildContext context, RepostedPost repost,
      AppPalette palette, Color onSurface) {
    final reposter = repost.reposter;
    final muted = TextStyle(fontSize: 13, color: palette.muted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: reposter == null
              ? null
              : () => onAuthorTap?.call(reposter.username),
          child: UserAvatar(name: reposter?.username, radius: _avatarRadius),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 26,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(reposter?.username ?? 'unknown',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(repost.repostedAt.timeAgo, style: muted),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(repost.quote!, style: _bodyStyle(onSurface)),
              const SizedBox(height: 10),
              QuotedPostPreview(post: post, onTap: onTap),
              const SizedBox(height: 2),
              _ActionBar(
                post: post,
                onLike: onLike,
                onSave: onSave,
                onRepost: onRepost,
                onQuote: onQuote,
                onShare: onShare,
                onReply: onTap,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static TextStyle _bodyStyle(Color color) =>
      TextStyle(fontSize: 15, height: 1.45, color: color);
}

/// Avatar, then name, review note, text, media, meta line and actions.
class _PostBlock extends StatelessWidget {
  const _PostBlock({
    required this.post,
    required this.avatarRadius,
    this.onLike,
    this.onSave,
    this.onRepost,
    this.onQuote,
    this.onShare,
    this.onReply,
    this.onAuthorTap,
    this.onMore,
  });

  final Post post;
  final double avatarRadius;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onQuote;
  final VoidCallback? onShare;
  final VoidCallback? onReply;
  final ValueChanged<String>? onAuthorTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: post.author == null
              ? null
              : () => onAuthorTap?.call(post.author!.username),
          child: UserAvatar(name: post.author?.username, radius: avatarRadius),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(post: post, onAuthorTap: onAuthorTap, onMore: onMore),
              if (post.isUnderReview || post.isRemoved) ...[
                const SizedBox(height: 4),
                Text(
                  post.isRemoved
                      ? 'Removed by moderators · only you can see this'
                      : 'Under review',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: post.isRemoved ? palette.accent2 : palette.warn,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(post.body, style: PostCard._bodyStyle(onSurface)),
              if (post.hasMedia) ...[
                const SizedBox(height: 10),
                _PostImage(url: post.mediaUrl!),
              ],
              _MetaLine(post: post),
              const SizedBox(height: 2),
              _ActionBar(
                post: post,
                onLike: onLike,
                onSave: onSave,
                onRepost: onRepost,
                onQuote: onQuote,
                onShare: onShare,
                onReply: onReply,
                compact: avatarRadius < 20,
              ),
            ],
          ),
        ),
      ],
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
              const SizedBox(height: 8),
              Text(post.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 15, height: 1.4, color: onSurface)),
              if (post.hasMedia) ...[
                const SizedBox(height: 10),
                _PostImage(url: post.mediaUrl!),
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
          Text(
              post.isEdited
                  ? '${post.createdAt.timeAgo} · edited'
                  : post.createdAt.timeAgo,
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
              size: 8,
              weight: FontWeight.w700,
              color: green,
              letterSpacing: 1)),
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
    this.onReply,
    this.compact = false,
  });

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onRepost;
  final VoidCallback? onQuote;
  final VoidCallback? onShare;
  final VoidCallback? onReply;

  /// Narrower buttons for posts shown inside a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final w = compact ? 48.0 : 60.0;

    return Transform.translate(
      offset: const Offset(-10, 0),
      child: Row(
        children: [
          _ActionButton(
            minWidth: w,
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
            minWidth: w,
            icon: Icons.mode_comment_outlined,
            count: post.replyCount,
            tooltip: 'Replies',
            onTap: onReply,
          ),
          Builder(
            builder: (buttonContext) => _ActionButton(
              minWidth: w,
              icon: Icons.repeat_rounded,
              count: post.repostCount,
              active: post.reposted,
              activeColor: palette.verified,
              tooltip: post.reposted ? 'Undo repost' : 'Repost',
              onTap: onRepost == null
                  ? null
                  : onQuote == null
                      ? onRepost
                      : () => _showRepostMenu(
                          buttonContext, post, onRepost!, onQuote!),
            ),
          ),
          const Spacer(),
          Transform.translate(
            offset: const Offset(20, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  minWidth: w,
                  icon: Icons.share_outlined,
                  tooltip: 'Share',
                  onTap: onShare,
                ),
                _ActionButton(
                  minWidth: w,
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
