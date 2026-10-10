import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent;

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_remote_data_source.dart';
import '../models/comment_model.dart';

/// Comments live in `content`, profiles in `identity`; PostgREST can't embed
/// across schemas, so authors are batch-fetched and merged here.
class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._remote, this._profiles);

  final CommentRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

  Future<List<Comment>> _hydrate(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const [];
    final profiles = await runRpc(
        () => _profiles.profilesByIds(CommentModel.profileIds(rows)));
    return rows
        .map((r) => CommentModel.fromJson(r, profiles: profiles))
        .toList();
  }

  @override
  Future<Result<List<Comment>>> getComments(int postId,
          {int? beforeId, int limit = CommentPolicy.pageSize}) =>
      guard(() async => _hydrate(
          await _remote.fetchForPost(postId, beforeId: beforeId, limit: limit)));

  @override
  Future<Result<List<Comment>>> getReplies(int rootId,
          {int? afterId, int limit = CommentPolicy.repliesPageSize}) =>
      guard(() async => _hydrate(
          await _remote.fetchReplies(rootId, afterId: afterId, limit: limit)));

  @override
  Future<Result<Comment>> createComment({
    required int postId,
    required String body,
    int? parentId,
  }) =>
      guard(() async =>
          (await _hydrate([await _remote.create(postId, body, parentId)])).first);

  @override
  Future<Result<Comment>> editComment(int commentId, String body) => guard(
      () async => (await _hydrate([await _remote.edit(commentId, body)])).first);

  @override
  Future<Result<void>> deleteComment(int commentId) =>
      guard(() => _remote.delete(commentId));

  @override
  Future<Result<CommentLikeResult>> toggleLike(int commentId) =>
      guard(() async {
        final row = await _remote.toggleLike(commentId);
        return CommentLikeResult(
          liked: row['liked'] as bool? ?? false,
          likeCount: asInt(row['like_count']) ?? 0,
        );
      });

  @override
  Stream<CommentEvent> watchPost(int postId) async* {
    await for (final change in _remote.watchPost(postId)) {
      if (change.type == PostgresChangeEvent.delete) {
        final id = asInt(change.old['id']);
        if (id != null) yield CommentRemoved(id);
        continue;
      }
      if (change.row.isEmpty) continue;
      try {
        yield CommentUpserted((await _hydrate([change.row])).first);
      } catch (_) {
        // Profile lookup failed: still deliver the row; the cubit keeps
        // whatever author it already had.
        yield CommentUpserted(CommentModel.fromJson(change.row));
      }
    }
  }
}
