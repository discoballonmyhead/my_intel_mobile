import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/feed/domain/repositories/post_repository.dart';
import 'package:mint/features/feed/domain/usecases/create_post.dart';

class _FakeRepository implements PostRepository {
  final uploads = <String>[];
  List<UploadedAttachment>? sentAttachments;
  PollDraft? sentPoll;
  bool failUploads = false;

  @override
  Future<Result<({String path, String url})>> uploadFile({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
  }) async {
    if (failUploads) return const Err(ServerFailure('upload failed'));
    final path = 'u1/${uploads.length}.$fileExtension';
    uploads.add(path);
    return Ok((path: path, url: 'https://x/storage/v1/object/public/mint-media/$path'));
  }

  @override
  Future<Result<Post>> createPost({
    required String body,
    String? region,
    String? tag,
    String? mediaUrl,
    String postType = 'general',
    List<UploadedAttachment> attachments = const [],
    PollDraft? poll,
  }) async {
    sentAttachments = attachments;
    sentPoll = poll;
    return Ok(Post(id: 1, body: body, createdAt: DateTime.utc(2026)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PendingAttachment _file(AttachmentKind kind, int size, [String ext = 'jpg']) =>
    PendingAttachment(kind: kind, bytes: Uint8List(size), extension: ext, fileName: 'f.$ext');

void main() {
  late _FakeRepository repo;
  late CreatePost createPost;

  setUp(() {
    repo = _FakeRepository();
    createPost = CreatePost(repo);
  });

  test('uploads attachments in order and sends them with the post', () async {
    final result = await createPost(CreatePostParams(body: 'hi', attachments: [
      _file(AttachmentKind.image, 10),
      _file(AttachmentKind.audio, 10, 'm4a'),
    ]));
    expect(result.isOk, isTrue);
    expect(repo.uploads, ['u1/0.jpg', 'u1/1.m4a']);
    expect(repo.sentAttachments!.map((a) => a.kind),
        [AttachmentKind.image, AttachmentKind.audio]);
    expect(repo.sentAttachments!.first.storagePath, 'u1/0.jpg');
  });

  test('a poll alone is enough to post', () async {
    final result = await createPost(
        const CreatePostParams(body: '', poll: PollDraft(options: ['Yes', 'No'])));
    expect(result.isOk, isTrue);
    expect(repo.sentPoll!.cleanOptions, ['Yes', 'No']);
  });

  test('rejects more than 4 attachments before uploading anything', () async {
    final result = await createPost(CreatePostParams(
        body: 'x', attachments: List.generate(5, (_) => _file(AttachmentKind.image, 1))));
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(repo.uploads, isEmpty);
  });

  test('rejects a file over its kind limit', () async {
    final result = await createPost(CreatePostParams(
        body: 'x', attachments: [_file(AttachmentKind.image, 10 * 1024 * 1024 + 1)]));
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(repo.uploads, isEmpty);
  });

  test('rejects a poll on a News post and an invalid poll', () async {
    final news = await createPost(const CreatePostParams(
        body: 'x', postType: 'news', poll: PollDraft(options: ['a', 'b'])));
    expect(news.failureOrNull?.message, contains('News'));
    final bad = await createPost(
        const CreatePostParams(body: 'x', poll: PollDraft(options: ['only one'])));
    expect(bad.failureOrNull, isA<ValidationFailure>());
  });

  test('allows 500 characters and rejects 501', () async {
    expect((await createPost(CreatePostParams(body: 'a' * 500))).isOk, isTrue);
    final tooLong = await createPost(CreatePostParams(body: 'a' * 501));
    expect(tooLong.failureOrNull?.message, 'Posts are limited to 500 characters.');
  });

  test('stops and reports when an upload fails', () async {
    repo.failUploads = true;
    final result = await createPost(
        CreatePostParams(body: 'x', attachments: [_file(AttachmentKind.image, 1)]));
    expect(result.failureOrNull?.message, 'upload failed');
    expect(repo.sentAttachments, isNull);
  });
}
