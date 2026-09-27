import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/post.dart';

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.body,
    required super.createdAt,
    super.authorId,
    super.author,
    super.region,
    super.tag,
    super.isOsint,
    super.postType,
    super.mediaUrl,
    super.likes,
    super.replyCount,
    super.repostCount,
    super.regionLat,
    super.regionLng,
    super.manualStoryId,
    super.liked,
    super.saved,
    super.reposted,
    super.editedAt,
    super.editCount,
    super.moderationStatus,
    super.deletedAt,
  });

  factory PostModel.fromJson(
    Map<String, dynamic> json, {
    Profile? author,
    bool liked = false,
    bool saved = false,
    bool reposted = false,
  }) {
    return PostModel(
      id: (json['id'] as num).toInt(),
      body: (json['body'] as String?) ?? '',
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      authorId: json['author_id'] as String?,
      author: author,
      region: json['region'] as String?,
      tag: json['tag'] as String?,
      isOsint: (json['is_osint'] as bool?) ?? false,
      postType: (json['post_type'] as String?) ?? 'general',
      mediaUrl: json['media_url'] as String?,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      repostCount: (json['repost_count'] as num?)?.toInt() ?? 0,
      regionLat: (json['region_lat'] as num?)?.toDouble(),
      regionLng: (json['region_lng'] as num?)?.toDouble(),
      manualStoryId: (json['manual_story_id'] as num?)?.toInt(),
      liked: liked,
      saved: saved,
      reposted: reposted,
      editedAt: parseTimestamp(json['edited_at']),
      editCount: (json['edit_count'] as num?)?.toInt() ?? 0,
      moderationStatus: (json['moderation_status'] as String?) ?? 'visible',
      deletedAt: parseTimestamp(json['deleted_at']),
    );
  }

  /// Insert payload. `likes`, `reply_count` and `repost_count` are seeded at 0
  /// to match the web client; the triggers handle clustering and scoring.
  static Map<String, dynamic> toInsertJson({
    required String authorId,
    required String body,
    String? region,
    String? tag,
    String? mediaUrl,
    bool isOsint = false,
    String postType = 'general',
    double? regionLat,
    double? regionLng,
    int? manualStoryId,
  }) {
    return {
      'author_id': authorId,
      'body': body,
      'region': region,
      'tag': tag,
      'is_osint': isOsint,
      'post_type': postType,
      'likes': 0,
      'reply_count': 0,
      'repost_count': 0,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (regionLat != null) 'region_lat': regionLat,
      if (regionLng != null) 'region_lng': regionLng,
      if (manualStoryId != null) 'manual_story_id': manualStoryId,
    };
  }
}

/// A row of `content.reposts` before the referenced post is attached.
class RepostRow {
  const RepostRow({
    required this.id,
    required this.userId,
    required this.postId,
    required this.createdAt,
    this.quoteBody,
  });

  factory RepostRow.fromJson(Map<String, dynamic> json) {
    return RepostRow(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      postId: (json['post_id'] as num).toInt(),
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      quoteBody: json['quote_body'] as String?,
    );
  }

  final int id;
  final String userId;
  final int postId;
  final DateTime createdAt;
  final String? quoteBody;
}
