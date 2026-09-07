import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

/// A row of `content.posts` with its author merged in and the viewer's own
/// interaction state resolved.
class Post extends Equatable {
  const Post({
    required this.id,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.author,
    this.region,
    this.tag,
    this.isOsint = false,
    this.postType = 'general',
    this.mediaUrl,
    this.likes = 0,
    this.replyCount = 0,
    this.repostCount = 0,
    this.regionLat,
    this.regionLng,
    this.manualStoryId,
    this.liked = false,
    this.saved = false,
    this.reposted = false,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final String? authorId;
  final Profile? author;
  final String? region;
  final String? tag;

  /// True for analyst intelligence posts, which the
  /// `trg_auto_link_post_to_stories` trigger clusters into stories.
  final bool isOsint;

  /// 'general' | 'news'
  final String postType;
  final String? mediaUrl;

  final int likes;
  final int replyCount;
  final int repostCount;

  final double? regionLat;
  final double? regionLng;
  final int? manualStoryId;

  // Viewer state, resolved from content.likes / saved_posts / reposts.
  final bool liked;
  final bool saved;
  final bool reposted;

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get hasCoordinates => regionLat != null && regionLng != null;

  Post copyWith({
    int? likes,
    int? replyCount,
    int? repostCount,
    bool? liked,
    bool? saved,
    bool? reposted,
    Profile? author,
  }) {
    return Post(
      id: id,
      body: body,
      createdAt: createdAt,
      authorId: authorId,
      author: author ?? this.author,
      region: region,
      tag: tag,
      isOsint: isOsint,
      postType: postType,
      mediaUrl: mediaUrl,
      likes: likes ?? this.likes,
      replyCount: replyCount ?? this.replyCount,
      repostCount: repostCount ?? this.repostCount,
      regionLat: regionLat,
      regionLng: regionLng,
      manualStoryId: manualStoryId,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      reposted: reposted ?? this.reposted,
    );
  }

  @override
  List<Object?> get props => [id, likes, replyCount, repostCount, liked, saved, reposted];
}

/// The feed interleaves original posts with reposts of other people's posts.
/// A sealed type makes the two cases explicit at the render site instead of
/// smuggling a `_type` string through the model.
sealed class FeedItem extends Equatable {
  const FeedItem(this.post);

  final Post post;

  /// Timestamp the feed sorts on: for a repost that is when it was reposted,
  /// not when the original was written.
  DateTime get sortedAt;

  @override
  List<Object?> get props => [post, sortedAt];
}

class OriginalPost extends FeedItem {
  const OriginalPost(super.post);

  @override
  DateTime get sortedAt => post.createdAt;
}

class RepostedPost extends FeedItem {
  const RepostedPost(
    super.post, {
    required this.repostId,
    required this.repostedAt,
    this.reposter,
    this.quote,
  });

  final int repostId;
  final DateTime repostedAt;
  final Profile? reposter;
  final String? quote;

  bool get hasQuote => quote != null && quote!.trim().isNotEmpty;

  @override
  DateTime get sortedAt => repostedAt;

  @override
  List<Object?> get props => [post, repostId, repostedAt, quote];
}
