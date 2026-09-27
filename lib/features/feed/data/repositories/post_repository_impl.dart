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
import '../models/post_model.dart';

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

      PostModel build(Map<String, dynamic> row) {
        final id = (row['id'] as num).toInt();
        return PostModel.fromJson(
          row,
          author: profiles[row['author_id']],
          liked: liked.contains(id),
          saved: saved.contains(id),
          reposted: reposted.contains(id),
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
      return PostModel.fromJson(
        row,
        author: profiles[row['author_id']],
        liked: liked.contains(postId),
        saved: saved.contains(postId),
        reposted: reposted.contains(postId),
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
      return rows
          .map((row) => PostModel.fromJson(row, author: profiles[authorId]))
          .toList();
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
      // Preserve the saved-at ordering rather than the id ordering.
      return ids
          .map((id) => byId[id])
          .whereType<Map<String, dynamic>>()
          .map((row) => PostModel.fromJson(
                row,
                author: profiles[row['author_id']],
                saved: true,
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

      final row = await _remote.insertPost(PostModel.toInsertJson(
        authorId: userId,
        body: body.trim(),
        region: region,
        tag: resolvedTag,
        mediaUrl: mediaUrl,
        postType: postType,
      ));

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
      final userId = _service.currentUserId;
      if (userId == null) {
        throw const ex.AuthException('You must be signed in to upload.');
      }
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      return _remote.uploadMedia(
        Uint8List.fromList(bytes),
        path,
        contentType,
      );
    });
  }

  @override
  Stream<Post> watchNewPosts() async* {
    await for (final row in _remote.watchInserts()) {
      final authorId = row['author_id'] as String?;
      final profiles = await _profiles.profilesByIds([authorId]);
      yield PostModel.fromJson(row, author: profiles[authorId]);
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
