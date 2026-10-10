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
    this.mediaBytes,
    this.mediaExtension,
    this.mediaContentType,
    this.postType = 'general',
  });

  final String body;
  final String? region;
  final String? tag;
  final String? mediaUrl;

  /// A photo picked in the composer. It is uploaded first and its public URL
  /// becomes [mediaUrl].
  final List<int>? mediaBytes;
  final String? mediaExtension;
  final String? mediaContentType;
  final String postType;

  bool get hasMedia => mediaUrl != null || mediaBytes != null;
}

class CreatePost implements UseCase<Post, CreatePostParams> {
  const CreatePost(this._repository);

  static const int maxLength = 2000;

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(CreatePostParams params) async {
    final body = params.body.trim();
    if (body.isEmpty && !params.hasMedia) {
      return const Err(ValidationFailure('Write something before posting.'));
    }
    if (body.length > maxLength) {
      return const Err(ValidationFailure('Posts are limited to 2000 characters.'));
    }
    var mediaUrl = params.mediaUrl;
    final bytes = params.mediaBytes;
    if (bytes != null) {
      final upload = await _repository.uploadMedia(
        bytes: bytes,
        fileExtension: params.mediaExtension ?? 'jpg',
        contentType: params.mediaContentType,
      );
      final failure = upload.failureOrNull;
      if (failure != null) return Err(failure);
      mediaUrl = upload.valueOrNull;
    }
    return _repository.createPost(
      body: body,
      region: params.region,
      tag: params.tag,
      mediaUrl: mediaUrl,
      postType: params.postType,
    );
  }
}
