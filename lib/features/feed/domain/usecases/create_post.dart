import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

class CreatePostParams {
  const CreatePostParams({
    required this.body,
    this.region,
    this.tag,
    this.mediaUrl,
    this.postType = 'general',
  });

  final String body;
  final String? region;
  final String? tag;
  final String? mediaUrl;
  final String postType;
}

class CreatePost implements UseCase<Post, CreatePostParams> {
  const CreatePost(this._repository);

  static const int maxLength = 2000;

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(CreatePostParams params) async {
    final body = params.body.trim();
    if (body.isEmpty && params.mediaUrl == null) {
      return const Err(ValidationFailure('Write something before posting.'));
    }
    if (body.length > maxLength) {
      return const Err(ValidationFailure('Posts are limited to 2000 characters.'));
    }
    return _repository.createPost(
      body: body,
      region: params.region,
      tag: params.tag,
      mediaUrl: params.mediaUrl,
      postType: params.postType,
    );
  }
}
