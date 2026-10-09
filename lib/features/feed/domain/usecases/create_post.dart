import 'dart:typed_data';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// A file picked in the composer, not uploaded yet.
class PendingAttachment {
  const PendingAttachment({
    required this.kind,
    required this.bytes,
    required this.extension,
    this.contentType,
    this.fileName,
    this.width,
    this.height,
    this.durationSeconds,
  });

  final AttachmentKind kind;
  final Uint8List bytes;
  final String extension;
  final String? contentType;
  final String? fileName;
  final int? width;
  final int? height;
  final double? durationSeconds;
}

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
    this.attachments = const [],
    this.poll,
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

  /// Up to [CreatePost.maxAttachments] files, uploaded in this order.
  final List<PendingAttachment> attachments;
  final PollDraft? poll;

  bool get hasMedia =>
      mediaUrl != null || mediaBytes != null || attachments.isNotEmpty;
}

class CreatePost implements UseCase<Post, CreatePostParams> {
  const CreatePost(this._repository);

  /// Same as the web composer; `social_create_post` rejects longer bodies.
  static const int maxLength = 500;
  static const int maxAttachments = 4;

  final PostRepository _repository;

  @override
  Future<Result<Post>> call(CreatePostParams params) async {
    final body = params.body.trim();
    final poll = params.poll;
    if (body.isEmpty && !params.hasMedia && poll == null) {
      return const Err(ValidationFailure('Write something before posting.'));
    }
    if (body.length > maxLength) {
      return const Err(ValidationFailure('Posts are limited to $maxLength characters.'));
    }
    if (params.attachments.length > maxAttachments) {
      return const Err(
          ValidationFailure('A post can have up to $maxAttachments attachments.'));
    }
    for (final a in params.attachments) {
      if (a.bytes.length > a.kind.maxBytes) {
        final mb = a.kind.maxBytes ~/ (1024 * 1024);
        return Err(ValidationFailure(
            '${a.fileName ?? 'That file'} is over the $mb MB limit.'));
      }
    }
    if (poll != null) {
      if (params.postType == 'news') {
        return const Err(ValidationFailure('News posts cannot have a poll.'));
      }
      if (!poll.isValid) {
        return const Err(ValidationFailure(
            'A poll needs 2 to 4 options of up to 80 characters.'));
      }
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
    final uploaded = <UploadedAttachment>[];
    for (final a in params.attachments) {
      final upload = await _repository.uploadFile(
        bytes: a.bytes,
        fileExtension: a.extension,
        contentType: a.contentType,
      );
      final failure = upload.failureOrNull;
      if (failure != null) return Err(failure);
      final file = upload.valueOrNull!;
      uploaded.add(UploadedAttachment(
        kind: a.kind,
        storagePath: file.path,
        url: file.url,
        fileName: a.fileName,
        width: a.width,
        height: a.height,
        durationSeconds: a.durationSeconds,
      ));
    }
    return _repository.createPost(
      body: body,
      region: params.region,
      tag: params.tag,
      mediaUrl: mediaUrl,
      postType: params.postType,
      attachments: uploaded,
      poll: poll,
    );
  }
}
