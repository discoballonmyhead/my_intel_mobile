import '../../../../core/utils/result.dart';
import '../entities/comment.dart';

abstract interface class CommentRepository {
  /// Top-level comments, newest first. Pass [beforeId] to page.
  Future<Result<List<Comment>>> getComments(
    int postId, {
    int? beforeId,
    int limit = CommentPolicy.pageSize,
  });

  /// Replies in a thread, oldest first. Pass [afterId] to page.
  Future<Result<List<Comment>>> getReplies(
    int rootId, {
    int? afterId,
    int limit = CommentPolicy.repliesPageSize,
  });

  /// [parentId] set = reply to that comment.
  Future<Result<Comment>> createComment({
    required int postId,
    required String body,
    int? parentId,
  });

  Future<Result<Comment>> editComment(int commentId, String body);
  Future<Result<void>> deleteComment(int commentId);
  Future<Result<CommentLikeResult>> toggleLike(int commentId);

  /// Live inserts / edits / deletes / like counts on one post.
  Stream<CommentEvent> watchPost(int postId);
}
