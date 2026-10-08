import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/feed/domain/repositories/post_repository.dart';
import 'package:mint/features/feed/domain/usecases/create_post.dart';
import 'package:mocktail/mocktail.dart';

class _MockPostRepository extends Mock implements PostRepository {}

void main() {
  late _MockPostRepository repo;
  late CreatePost createPost;
  final post = Post(id: 1, body: 'Flooding on SV Road', createdAt: DateTime(2026, 10, 8));

  setUp(() {
    repo = _MockPostRepository();
    createPost = CreatePost(repo);
    when(() => repo.createPost(
          body: any(named: 'body'),
          region: any(named: 'region'),
          tag: any(named: 'tag'),
          mediaUrl: any(named: 'mediaUrl'),
          postType: any(named: 'postType'),
        )).thenAnswer((_) async => Result.ok(post));
  });

  group('validation', () {
    test('rejects an empty post without a photo', () async {
      final result = await createPost(const CreatePostParams(body: '   '));

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repo.createPost(body: any(named: 'body')));
    });

    test('rejects a post over the length limit', () async {
      final result = await createPost(
          CreatePostParams(body: 'a' * (CreatePost.maxLength + 1)));

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('allows a photo with no text', () async {
      when(() => repo.uploadMedia(
            bytes: any(named: 'bytes'),
            fileExtension: any(named: 'fileExtension'),
            contentType: any(named: 'contentType'),
          )).thenAnswer((_) async => const Result.ok('https://cdn/p.jpg'));

      final result = await createPost(
          const CreatePostParams(body: '', mediaBytes: [1, 2, 3]));

      expect(result.isOk, isTrue);
    });
  });

  group('photo upload', () {
    test('uploads the photo, then posts with its URL', () async {
      when(() => repo.uploadMedia(
            bytes: any(named: 'bytes'),
            fileExtension: any(named: 'fileExtension'),
            contentType: any(named: 'contentType'),
          )).thenAnswer((_) async => const Result.ok('https://cdn/p.png'));

      final result = await createPost(const CreatePostParams(
        body: 'Flooding on SV Road',
        region: 'Mumbai, India',
        mediaBytes: [1, 2, 3],
        mediaExtension: 'png',
        mediaContentType: 'image/png',
      ));

      expect(result.valueOrNull, post);
      verify(() => repo.uploadMedia(
            bytes: [1, 2, 3],
            fileExtension: 'png',
            contentType: 'image/png',
          )).called(1);
      verify(() => repo.createPost(
            body: 'Flooding on SV Road',
            region: 'Mumbai, India',
            tag: null,
            mediaUrl: 'https://cdn/p.png',
            postType: 'general',
          )).called(1);
    });

    test('stops without posting when the upload fails', () async {
      when(() => repo.uploadMedia(
            bytes: any(named: 'bytes'),
            fileExtension: any(named: 'fileExtension'),
            contentType: any(named: 'contentType'),
          )).thenAnswer((_) async => const Result.err(NetworkFailure()));

      final result = await createPost(
          const CreatePostParams(body: 'x', mediaBytes: [1]));

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => repo.createPost(
            body: any(named: 'body'),
            region: any(named: 'region'),
            tag: any(named: 'tag'),
            mediaUrl: any(named: 'mediaUrl'),
            postType: any(named: 'postType'),
          ));
    });

    test('text-only posts never upload', () async {
      await createPost(const CreatePostParams(body: 'Just text'));

      verifyNever(() => repo.uploadMedia(
            bytes: any(named: 'bytes'),
            fileExtension: any(named: 'fileExtension'),
            contentType: any(named: 'contentType'),
          ));
    });
  });
}
