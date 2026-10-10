import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

/// Server rules mirrored in the UI.
class CommentPolicy {
  const CommentPolicy._();
  static const int maxLength = 2000;
  static const int pageSize = 30;
  static const int repliesPageSize = 50;
}

/// A row of `content.comments`. Threads are two levels: a root comment and
/// a flat list of replies (each reply remembers who it was answering).
class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.postId,
    required this.createdAt,
    this.authorId,
    this.author,
    this.parentId,
    this.rootId,
    this.replyToUserId,
    this.replyToProfile,
    this.body,
    this.likeCount = 0,
    this.replyCount = 0,
    this.editedAt,
    this.deletedAt,
    this.moderationStatus = 'visible',
    this.liked = false,
  });

  final int id;
  final int postId;
  final DateTime createdAt;

  /// Null once the author deleted their account.
  final String? authorId;
  final Profile? author;

  /// The comment this one answers (null for top-level).
  final int? parentId;

  /// The thread's root comment (null for top-level).
  final int? rootId;
  final String? replyToUserId;
  final Profile? replyToProfile;

  /// Null when deleted (placeholder kept so the thread stays readable).
  final String? body;
  final int likeCount;

  /// Replies in this thread (root comments only).
  final int replyCount;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  /// 'visible' | 'removed'
  final String moderationStatus;

  /// Whether the viewer liked it.
  final bool liked;

  bool get isRoot => rootId == null;
  bool get isDeleted => deletedAt != null;
  bool get isRemoved => moderationStatus == 'removed';
  bool get isEdited => editedAt != null && !isDeleted;
  bool get isGone => isDeleted || isRemoved;

  /// The thread this comment belongs to.
  int get threadId => rootId ?? id;

  bool isMine(String? userId) => userId != null && authorId == userId;

  bool canEdit(String? userId) => isMine(userId) && !isGone;

  /// Author, the post's author, or staff (mirrors `comment_delete`).
  bool canDelete(String? userId, {String? postAuthorId, bool isStaff = false}) =>
      !isDeleted &&
      userId != null &&
      (isMine(userId) || postAuthorId == userId || isStaff);

  String get displayBody {
    if (isDeleted) return 'Comment deleted';
    if (isRemoved && body == null) return 'Removed by moderators';
    return body ?? '';
  }

  Comment copyWith({
    String? body,
    int? likeCount,
    int? replyCount,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? moderationStatus,
    bool? liked,
    Profile? author,
    Profile? replyToProfile,
    bool clearBody = false,
  }) {
    return Comment(
      id: id,
      postId: postId,
      createdAt: createdAt,
      authorId: authorId,
      author: author ?? this.author,
      parentId: parentId,
      rootId: rootId,
      replyToUserId: replyToUserId,
      replyToProfile: replyToProfile ?? this.replyToProfile,
      body: clearBody ? null : body ?? this.body,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      liked: liked ?? this.liked,
    );
  }

  /// Merges a fresh server row (e.g. from realtime, which carries no
  /// viewer state) with what the screen already knows.
  Comment mergedOnto(Comment previous) => Comment(
        id: id,
        postId: postId,
        createdAt: createdAt,
        authorId: authorId,
        author: author ?? previous.author,
        parentId: parentId,
        rootId: rootId,
        replyToUserId: replyToUserId,
        replyToProfile: replyToProfile ?? previous.replyToProfile,
        body: body,
        likeCount: likeCount,
        replyCount: replyCount,
        editedAt: editedAt,
        deletedAt: deletedAt,
        moderationStatus: moderationStatus,
        liked: previous.liked,
      );

  @override
  List<Object?> get props => [
        id,
        body,
        likeCount,
        replyCount,
        editedAt,
        deletedAt,
        moderationStatus,
        liked,
        author,
        replyToProfile,
      ];
}

class CommentLikeResult {
  const CommentLikeResult({required this.liked, required this.likeCount});
  final bool liked;
  final int likeCount;
}

/// Realtime changes to a post's comments.
sealed class CommentEvent {
  const CommentEvent();
}

class CommentUpserted extends CommentEvent {
  const CommentUpserted(this.comment);
  final Comment comment;
}

class CommentRemoved extends CommentEvent {
  const CommentRemoved(this.commentId);
  final int commentId;
}
