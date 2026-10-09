import 'dart:typed_data';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_edit.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_data_source.dart';
import '../models/post_extras_model.dart';
import '../models/post_model.dart';

/// Attachments and poll for a batch of posts, keyed by post id.
typedef _Extras = ({
  Map<int, List<PostAttachment>> attachments,
  Map<int, PostPoll> polls,
});

/// Assembles the feed.
///
/// `content.posts.author_id` references `identity.profiles`, and PostgREST
/// cannot embed across a schema boundary, so authors are fetched in one batch
/// and merged here — the same strategy the web client uses, kept out of the
/// UI entirely.
class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl(this._remote, this._profiles, this._service);

  final PostRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;
  final SupabaseService _service;

  @override
  Future<Result<List<FeedItem>>> getFeed({
    int limit = AppConstants.feedPageSize,
  }) {
    return guard(() async {
      final rows =
          (await _remote.fetchPosts(limit: limit)).where(_isVisible).toList();
      final repostRows = await _remote.fetchRecentReposts(limit: limit);

      // Posts referenced by reposts may not be in the first page of the feed.
      final repostedIds = repostRows.map((r) => r.postId).toSet().toList();
      final repostedRows = (await _remote.fetchPostsByIds(repostedIds))
          .where(_isVisible)
          .toList();
      final repostedById = {
        for (final row in repostedRows) (row['id'] as num).toInt(): row,
      };

      final liked = await _remote.likedPostIds();
      final saved = await _remote.savedPostIds();
      final reposted = await _remote.repostedPostIds();

      final authorIds = <String?>[
        ...rows.map((r) => r['author_id'] as String?),
        ...repostedRows.map((r) => r['author_id'] as String?),
        ...repostRows.map((r) => r.userId),
      ];
      final profiles = await _profiles.profilesByIds(authorIds);
      final extras = await _extrasFor([...rows, ...repostedRows]);

      PostModel build(Map<String, dynamic> row) {
        final id = (row['id'] as num).toInt();
        return PostModel.fromJson(
          row,
          author: profiles[row['author_id']],
          liked: liked.contains(id),
          saved: saved.contains(id),
          reposted: reposted.contains(id),
          attachments: extras.attachments[id] ?? const [],
          poll: extras.polls[id],
        );
      }

      final items = <FeedItem>[
        ...rows.map((row) => OriginalPost(build(row))),
        // Skip reposts of your own post — the original already shows.
        ...repostRows
            .where((r) {
              final original = repostedById[r.postId];
              return original != null && original['author_id'] != r.userId;
            })
            .map((r) => RepostedPost(
                  build(repostedById[r.postId]!),
                  repostId: r.id,
                  repostedAt: r.createdAt,
                  reposter: profiles[r.userId],
                  quote: r.quoteBody,
                )),
      ]..sort((a, b) => b.sortedAt.compareTo(a.sortedAt));

      return items;
    });
  }

  @override
  Future<Result<Post>> getPost(int postId) {
    return guard(() async {
      final row = await _remote.fetchPost(postId);
      if (row == null) throw const ex.NotFoundException('Post not found.');
      final profiles = await _profiles.profilesByIds([row['author_id'] as String?]);
      final liked = await _remote.likedPostIds();
      final saved = await _remote.savedPostIds();
      final reposted = await _remote.repostedPostIds();
      final extras = await _extrasFor([row]);
      return PostModel.fromJson(
        row,
        author: profiles[row['author_id']],
        liked: liked.contains(postId),
        saved: saved.contains(postId),
        reposted: reposted.contains(postId),
        attachments: extras.attachments[postId] ?? const [],
        poll: extras.polls[postId],
      );
    });
  }

  @override
  Future<Result<List<Post>>> getPostsByAuthor(String authorId, {int limit = 20}) {
    return guard(() async {
      final rows = (await _remote.fetchPostsByAuthor(authorId, limit: limit))
          .where(_isVisible)
          .toList();
      final profiles = await _profiles.profilesByIds([authorId]);
      final extras = await _extrasFor(rows);
      return rows.map((row) {
        final id = (row['id'] as num).toInt();
        return PostModel.fromJson(
          row,
          author: profiles[authorId],
          attachments: extras.attachments[id] ?? const [],
          poll: extras.polls[id],
        );
      }).toList();
    });
  }

  @override
  Future<Result<List<Post>>> getSavedPosts() {
    return guard(() async {
      final ids = await _remote.savedPostIdsOrdered();
      if (ids.isEmpty) return <Post>[];
      final rows =
          (await _remote.fetchPostsByIds(ids)).where(_isVisible).toList();
      final byId = {for (final r in rows) (r['id'] as num).toInt(): r};
      final profiles =
          await _profiles.profilesByIds(rows.map((r) => r['author_id'] as String?));
      final extras = await _extrasFor(rows);
      // Preserve the saved-at ordering rather than the id ordering.
      return ids
          .map((id) => byId[id])
          .whereType<Map<String, dynamic>>()
          .map((row) => PostModel.fromJson(
                row,
                author: profiles[row['author_id']],
                saved: true,
                attachments:
                    extras.attachments[(row['id'] as num).toInt()] ?? const [],
                poll: extras.polls[(row['id'] as num).toInt()],
              ))
          .toList();
    });
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
  }) {
    return guard(() async {
      final userId = _service.currentUserId;
      if (userId == null) {
        throw const ex.AuthException('You must be signed in to post.');
      }

      // Fall back to the first #hashtag when no tag was picked, matching the
      // web composer's behaviour.
      final resolvedTag = tag ??
          RegExp(r'#(\w+)').firstMatch(body)?.group(1)?.toUpperCase();

      final row = await _remote.insertPost({
        ...PostModel.toInsertJson(
          authorId: userId,
          body: body.trim(),
          region: region,
          tag: resolvedTag,
          mediaUrl: mediaUrl,
          postType: postType,
        ),
        if (attachments.isNotEmpty)
          'attachments': [for (final a in attachments) a.toJson()],
        if (poll != null) 'poll': poll.toJson(),
      });

      final profiles = await _profiles.profilesByIds([userId]);
      return PostModel.fromJson(row, author: profiles[userId]);
    });
  }

  @override
  Future<Result<Post>> toggleLike(Post post) {
    return guard(() async {
      final nextLiked = !post.liked;
      final nextCount = nextLiked
          ? post.likes + 1
          : (post.likes - 1).clamp(0, 1 << 30);

      if (nextLiked) {
        await _remote.like(post.id);
      } else {
        await _remote.unlike(post.id);
      }
      await _remote.setCounter(post.id, 'likes', nextCount);

      return post.copyWith(liked: nextLiked, likes: nextCount);
    });
  }

  @override
  Future<Result<Post>> toggleSave(Post post) {
    return guard(() async {
      if (post.saved) {
        await _remote.unsave(post.id);
      } else {
        await _remote.save(post.id);
      }
      return post.copyWith(saved: !post.saved);
    });
  }

  @override
  Future<Result<Post>> toggleRepost(Post post, {String? quote}) {
    return guard(() async {
      final nextReposted = !post.reposted;
      final nextCount = nextReposted
          ? post.repostCount + 1
          : (post.repostCount - 1).clamp(0, 1 << 30);

      if (nextReposted) {
        await _remote.repost(post.id, quote: quote);
      } else {
        await _remote.undoRepost(post.id);
      }
      await _remote.setCounter(post.id, 'repost_count', nextCount);

      return post.copyWith(reposted: nextReposted, repostCount: nextCount);
    });
  }

  @override
  Future<Result<String>> uploadMedia({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
  }) {
    return guard(() async {
      final path = _uploadPath(fileExtension);
      return _remote.uploadMedia(
        Uint8List.fromList(bytes),
        path,
        contentType,
      );
    });
  }

  @override
  Future<Result<({String path, String url})>> uploadFile({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
  }) {
    return guard(() async {
      final path = _uploadPath(fileExtension);
      final url = await _remote.uploadMedia(
        Uint8List.fromList(bytes),
        path,
        contentType,
      );
      return (path: path, url: url);
    });
  }

  int _uploadSeq = 0;

  /// `{user_id}/{ms}_{n}.{ext}`: storage only accepts uploads into the
  /// viewer's own folder, and the counter keeps several files picked in the
  /// same millisecond apart.
  String _uploadPath(String fileExtension) {
    final userId = _service.currentUserId;
    if (userId == null) {
      throw const ex.AuthException('You must be signed in to upload.');
    }
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '$userId/${ms}_${_uploadSeq++}.$fileExtension';
  }

  @override
  Future<Result<Post>> votePoll(Post post, int optionId) {
    return guard(() async {
      final row = await _remote.votePoll(post.id, optionId);
      final poll = PostExtrasModel.pollFromJson(row);
      return poll == null ? post : post.copyWith(poll: poll);
    });
  }

  /// Attachments and polls live in their own tables. A failed lookup leaves
  /// the posts without them rather than failing the whole feed.
  Future<_Extras> _extrasFor(Iterable<Map<String, dynamic>> rows) async {
    final ids = rows.map((r) => (r['id'] as num).toInt()).toSet().toList();
    try {
      final (attachments, polls) =
          await (_remote.fetchAttachments(ids), _remote.fetchPolls(ids)).wait;
      return (
        attachments: attachments.map(
            (id, list) => MapEntry(id, PostExtrasModel.attachmentsFromJson(list))),
        polls: {
          for (final entry in polls.entries)
            if (PostExtrasModel.pollFromJson(entry.value) case final poll?)
              entry.key: poll,
        },
      );
    } on Object {
      return (attachments: const <int, List<PostAttachment>>{}, polls: const <int, PostPoll>{});
    }
  }

  @override
  Stream<Post> watchNewPosts() async* {
    await for (final row in _remote.watchInserts()) {
      final authorId = row['author_id'] as String?;
      final profiles = await _profiles.profilesByIds([authorId]);
      // The insert's transaction has committed, so its attachments and poll
      // are already readable.
      final id = (row['id'] as num).toInt();
      final extras = await _extrasFor([row]);
      yield PostModel.fromJson(
        row,
        author: profiles[authorId],
        attachments: extras.attachments[id] ?? const [],
        poll: extras.polls[id],
      );
    }
  }

  /// Belt and braces: the feed RPCs should already exclude deleted / removed
  /// posts (see migration 02), but older functions may not, so the client
  /// drops them too. Authors still see their own removed posts.
  bool _isVisible(Map<String, dynamic> row) {
    if (row['deleted_at'] != null) return false;
    if (row['moderation_status'] == 'removed') {
      return row['author_id'] == _service.currentUserId;
    }
    return true;
  }

  @override
  Future<Result<Post>> editPost(Post post, String body) {
    return guard(() async {
      final row = await _remote.editPost(post.id, body);
      final updated = PostModel.fromJson(row, author: post.author);
      // Keep the viewer's interaction state; the RPC row doesn't carry it.
      return updated.copyWith(
        liked: post.liked,
        saved: post.saved,
        reposted: post.reposted,
      );
    });
  }

  @override
  Future<Result<void>> deletePost(int postId) =>
      guard(() => _remote.deletePost(postId));

  @override
  Future<Result<List<PostEdit>>> getEditHistory(int postId) =>
      guard(() => _remote.fetchEditHistory(postId));
}
