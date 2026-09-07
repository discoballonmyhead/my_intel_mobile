import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

class ToggleLike implements UseCase<Post, Post> {
  const ToggleLike(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(Post post) => _repository.toggleLike(post);
}

class ToggleSave implements UseCase<Post, Post> {
  const ToggleSave(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(Post post) => _repository.toggleSave(post);
}

class ToggleRepostParams {
  const ToggleRepostParams({required this.post, this.quote});
  final Post post;
  final String? quote;
}

class ToggleRepost implements UseCase<Post, ToggleRepostParams> {
  const ToggleRepost(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(ToggleRepostParams params) =>
      _repository.toggleRepost(params.post, quote: params.quote);
}
