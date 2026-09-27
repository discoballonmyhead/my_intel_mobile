import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../entities/post_edit.dart';
import '../repositories/post_repository.dart';
import 'create_post.dart';

class EditPostParams {
  const EditPostParams({required this.post, required this.body});
  final Post post;
  final String body;
}

/// Author-only. The previous text is kept in `content.post_edits`.
class EditPost implements UseCase<Post, EditPostParams> {
  const EditPost(this._repository);
  final PostRepository _repository;

  @override
  Future<Result<Post>> call(EditPostParams params) async {
    final body = params.body.trim();
    if (body.isEmpty) {
      return const Err(ValidationFailure('A post cannot be empty.'));
    }
    if (body.length > CreatePost.maxLength) {
      return const Err(ValidationFailure('Posts are limited to 2000 characters.'));
    }
    if (body == params.post.body.trim()) return Ok(params.post);
    return _repository.editPost(params.post, body);
  }
}

/// Author-only soft delete.
class DeletePost implements UseCase<void, int> {
  const DeletePost(this._repository);
  final PostRepository _repository;

  @override
  Future<Result<void>> call(int postId) => _repository.deletePost(postId);
}

/// Author or staff only.
class GetPostEditHistory implements UseCase<List<PostEdit>, int> {
  const GetPostEditHistory(this._repository);
  final PostRepository _repository;

  @override
  Future<Result<List<PostEdit>>> call(int postId) =>
      _repository.getEditHistory(postId);
}
