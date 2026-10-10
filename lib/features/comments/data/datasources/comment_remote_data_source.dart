import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';

/// Raw `content.comments` rows. Writes go through `public.comment_*` RPCs
/// (the table has no insert/update policies).
abstract interface class CommentRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchForPost(int postId,
      {int? beforeId, required int limit});
  Future<List<Map<String, dynamic>>> fetchReplies(int rootId,
      {int? afterId, required int limit});
  Future<Map<String, dynamic>> create(int postId, String body, int? parentId);
  Future<Map<String, dynamic>> edit(int commentId, String body);
  Future<void> delete(int commentId);
  Future<Map<String, dynamic>> toggleLike(int commentId);

  /// (eventType, newRecord, oldRecord) for one post's comments.
  Stream<({PostgresChangeEvent type, Map<String, dynamic> row, Map<String, dynamic> old})>
      watchPost(int postId);
}

class CommentRemoteDataSourceImpl implements CommentRemoteDataSource {
  CommentRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> fetchForPost(int postId,
          {int? beforeId, required int limit}) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(CommentRpc.forPost,
              params: {
                'p_post_id': postId,
                'p_limit': limit,
                'p_before_id': beforeId,
              })));

  @override
  Future<List<Map<String, dynamic>>> fetchReplies(int rootId,
          {int? afterId, required int limit}) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(CommentRpc.replies,
              params: {
                'p_root_id': rootId,
                'p_limit': limit,
                'p_after_id': afterId,
              })));

  @override
  Future<Map<String, dynamic>> create(int postId, String body, int? parentId) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(CommentRpc.create, params: {
          'p_post_id': postId,
          'p_body': body,
          'p_parent_id': parentId,
        });
        return asRow(res) ??
            (throw const ex.ServerException('Comment was not saved.'));
      });

  @override
  Future<Map<String, dynamic>> edit(int commentId, String body) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(CommentRpc.edit,
            params: {'p_comment_id': commentId, 'p_body': body});
        return asRow(res) ??
            (throw const ex.NotFoundException('Comment not found.'));
      });

  @override
  Future<void> delete(int commentId) => runRpc(() async {
        await _service.rpc<dynamic>(CommentRpc.delete,
            params: {'p_comment_id': commentId});
      });

  @override
  Future<Map<String, dynamic>> toggleLike(int commentId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(CommentRpc.toggleLike,
            params: {'p_comment_id': commentId});
        return asRow(res) ?? const {};
      });

  @override
  Stream<({PostgresChangeEvent type, Map<String, dynamic> row, Map<String, dynamic> old})>
      watchPost(int postId) {
    final controller = StreamController<
        ({PostgresChangeEvent type, Map<String, dynamic> row, Map<String, dynamic> old})>.broadcast();
    RealtimeChannel? channel;

    controller.onListen = () {
      channel = _service
          .channel('content:comments:$postId:${DateTime.now().microsecondsSinceEpoch}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.content,
          table: DbTables.comments,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) => controller.add((
            type: payload.eventType,
            row: payload.newRecord,
            old: payload.oldRecord,
          )),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _service.removeChannel(c);
      await controller.close();
    };
    return controller.stream;
  }
}
