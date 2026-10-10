import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// One post with author and viewer state — used by the post detail screen.
class GetPost implements UseCase<Post, int> {
  const GetPost(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(int postId) => _repository.getPost(postId);
}
