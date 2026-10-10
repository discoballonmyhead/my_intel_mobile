import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

class GetFeed implements UseCase<List<FeedItem>, NoParams> {
  const GetFeed(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<List<FeedItem>>> call(NoParams params) =>
      _repository.getFeed(limit: AppConstants.feedPageSize);
}

class GetSavedPosts implements UseCase<List<Post>, NoParams> {
  const GetSavedPosts(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<List<Post>>> call(NoParams params) =>
      _repository.getSavedPosts();
}

class GetPostsByAuthor implements UseCase<List<Post>, String> {
  const GetPostsByAuthor(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<List<Post>>> call(String authorId) =>
      _repository.getPostsByAuthor(authorId);
}

class WatchNewPosts implements StreamUseCase<Post, NoParams> {
  const WatchNewPosts(this._repository);

  final PostRepository _repository;

  @override
  Stream<Post> call(NoParams params) => _repository.watchNewPosts();
}

class GetRepostsByUser implements UseCase<List<RepostedPost>, String> {
  const GetRepostsByUser(this._repository);

  final PostRepository _repository;

  @override
  Future<Result<List<RepostedPost>>> call(String userId) =>
      _repository.getRepostsByUser(userId);
}
