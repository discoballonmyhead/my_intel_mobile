import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/comment.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.postId,
    required super.createdAt,
    super.authorId,
    super.author,
    super.parentId,
    super.rootId,
    super.replyToUserId,
    super.replyToProfile,
    super.body,
    super.likeCount,
    super.replyCount,
    super.editedAt,
    super.deletedAt,
    super.moderationStatus,
    super.liked,
  });

  /// Profiles the repository needs to fetch for a batch of rows.
  static Iterable<String?> profileIds(Iterable<Map<String, dynamic>> rows) sync* {
    for (final r in rows) {
      yield r['author_id'] as String?;
      yield r['reply_to_user_id'] as String?;
    }
  }

  factory CommentModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, Profile> profiles = const {},
  }) {
    final authorId = json['author_id'] as String?;
    final replyTo = json['reply_to_user_id'] as String?;
    return CommentModel(
      id: asInt(json['id']) ?? 0,
      postId: asInt(json['post_id']) ?? 0,
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      authorId: authorId,
      author: profiles[authorId],
      parentId: asInt(json['parent_id']),
      rootId: asInt(json['root_id']),
      replyToUserId: replyTo,
      replyToProfile: profiles[replyTo],
      body: json['body'] as String?,
      likeCount: asInt(json['like_count']) ?? 0,
      replyCount: asInt(json['reply_count']) ?? 0,
      editedAt: parseTimestamp(json['edited_at']),
      deletedAt: parseTimestamp(json['deleted_at']),
      moderationStatus: (json['moderation_status'] as String?) ?? 'visible',
      liked: (json['liked'] as bool?) ?? false,
    );
  }
}
