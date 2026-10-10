import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

Result<T>? _validateBody<T>(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return Err<T>(const ValidationFailure('Write something first.'));
  if (trimmed.length > CommentPolicy.maxLength) {
    return Err<T>(const ValidationFailure('Comments are limited to 2000 characters.'));
  }
  return null;
}

class GetCommentsParams {
  const GetCommentsParams({required this.postId, this.beforeId});
  final int postId;
  final int? beforeId;
}

class GetComments implements UseCase<List<Comment>, GetCommentsParams> {
  const GetComments(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<List<Comment>>> call(GetCommentsParams p) =>
      _repository.getComments(p.postId, beforeId: p.beforeId);
}

class GetRepliesParams {
  const GetRepliesParams({required this.rootId, this.afterId});
  final int rootId;
  final int? afterId;
}

class GetReplies implements UseCase<List<Comment>, GetRepliesParams> {
  const GetReplies(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<List<Comment>>> call(GetRepliesParams p) =>
      _repository.getReplies(p.rootId, afterId: p.afterId);
}

class CreateCommentParams {
  const CreateCommentParams({
    required this.postId,
    required this.body,
    this.parentId,
  });
  final int postId;
  final String body;
  final int? parentId;
}

class CreateComment implements UseCase<Comment, CreateCommentParams> {
  const CreateComment(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<Comment>> call(CreateCommentParams p) async =>
      _validateBody<Comment>(p.body) ??
      await _repository.createComment(
        postId: p.postId,
        body: p.body.trim(),
        parentId: p.parentId,
      );
}

class EditCommentParams {
  const EditCommentParams({required this.comment, required this.body});
  final Comment comment;
  final String body;
}

class EditComment implements UseCase<Comment, EditCommentParams> {
  const EditComment(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<Comment>> call(EditCommentParams p) async {
    final invalid = _validateBody<Comment>(p.body);
    if (invalid != null) return invalid;
    if (p.body.trim() == (p.comment.body ?? '').trim()) return Ok(p.comment);
    return _repository.editComment(p.comment.id, p.body.trim());
  }
}

class DeleteComment implements UseCase<void, int> {
  const DeleteComment(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<void>> call(int commentId) => _repository.deleteComment(commentId);
}

class ToggleCommentLike implements UseCase<CommentLikeResult, int> {
  const ToggleCommentLike(this._repository);
  final CommentRepository _repository;

  @override
  Future<Result<CommentLikeResult>> call(int commentId) =>
      _repository.toggleLike(commentId);
}

class WatchPostComments implements StreamUseCase<CommentEvent, int> {
  const WatchPostComments(this._repository);
  final CommentRepository _repository;

  @override
  Stream<CommentEvent> call(int postId) => _repository.watchPost(postId);
}
