import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../../../../core/network/rpc_runner.dart';
import '../models/post_edit_model.dart';
import '../models/post_model.dart';

abstract interface class PostRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchPosts({int limit});
  Future<Map<String, dynamic>?> fetchPost(int postId);
  Future<List<Map<String, dynamic>>> fetchPostsByIds(List<int> ids);
  Future<List<Map<String, dynamic>>> fetchPostsByAuthor(String authorId,
      {int limit});
  Future<List<RepostRow>> fetchRecentReposts({int limit});

  Future<Set<int>> likedPostIds();
  Future<Set<int>> savedPostIds();
  Future<Set<int>> repostedPostIds();
  Future<List<int>> savedPostIdsOrdered();

  Future<Map<String, dynamic>> insertPost(Map<String, dynamic> payload);
  Future<void> like(int postId);
  Future<void> unlike(int postId);
  Future<void> save(int postId);
  Future<void> unsave(int postId);
  Future<void> repost(int postId, {String? quote});
  Future<void> undoRepost(int postId);
  Future<void> setCounter(int postId, String column, int value);
  Future<String> uploadMedia(Uint8List bytes, String path, String? contentType);
  Stream<Map<String, dynamic>> watchInserts();

  Future<Map<String, dynamic>> editPost(int postId, String body);
  Future<void> deletePost(int postId);
  Future<List<PostEditModel>> fetchEditHistory(int postId);
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  PostRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> fetchPosts({int limit = 50}) async {
    try {
      final res = await _service
          .rpc<List<dynamic>>('feed_get_posts', params: {'p_limit': limit});
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchPost(int postId) async {
    try {
      final res =
          await _service.rpc('feed_get_post', params: {'p_post_id': postId});
      return res as Map<String, dynamic>?;
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPostsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final res = await _service
        .rpc<List<dynamic>>('feed_get_posts_by_ids', params: {'p_ids': ids});
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPostsByAuthor(String authorId,
      {int limit = 20}) async {
    final res = await _service.rpc<List<dynamic>>('feed_get_posts_by_author',
        params: {'p_author_id': authorId, 'p_limit': limit});
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<List<RepostRow>> fetchRecentReposts({int limit = 50}) async {
    final res = await _service.rpc<List<dynamic>>('feed_get_recent_reposts',
        params: {'p_limit': limit});
    final rows = List<Map<String, dynamic>>.from(res ?? []);
    return rows.map(RepostRow.fromJson).toList();
  }

  @override
  Future<Set<int>> likedPostIds() async {
    final res =
        await _service.rpc<List<dynamic>>('engagement_get_liked_post_ids');
    return res?.map((e) => e as int).toSet() ?? <int>{};
  }

  @override
  Future<Set<int>> savedPostIds() async {
    final res =
        await _service.rpc<List<dynamic>>('engagement_get_saved_post_ids');
    return res?.map((e) => e as int).toSet() ?? <int>{};
  }

  @override
  Future<Set<int>> repostedPostIds() async {
    final res =
        await _service.rpc<List<dynamic>>('engagement_get_reposted_post_ids');
    return res?.map((e) => e as int).toSet() ?? <int>{};
  }

  @override
  Future<List<int>> savedPostIdsOrdered() async {
    final res = await _service
        .rpc<List<dynamic>>('engagement_get_saved_post_ids_ordered');
    return res?.map((e) => e as int).toList() ?? [];
  }

  @override
  Future<Map<String, dynamic>> insertPost(Map<String, dynamic> payload) async {
    try {
      final res = await _service
          .rpc('social_create_post', params: {'p_payload': payload});
      return res as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ex.PermissionException(
            'You do not have permission to publish that.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> like(int postId) async {
    await _service.rpc('engagement_toggle_like', params: {'p_post_id': postId});
  }

  @override
  Future<void> unlike(int postId) async {
    await _service.rpc('engagement_toggle_like', params: {'p_post_id': postId});
  }

  @override
  Future<void> save(int postId) async {
    await _service.rpc('engagement_save_post', params: {'p_post_id': postId});
  }

  @override
  Future<void> unsave(int postId) async {
    await _service.rpc('engagement_unsave_post', params: {'p_post_id': postId});
  }

  @override
  Future<void> repost(int postId, {String? quote}) async {
    await _service.rpc('engagement_repost',
        params: {'p_post_id': postId, 'p_quote': quote});
  }

  @override
  Future<void> undoRepost(int postId) async {
    await _service.rpc('engagement_undo_repost', params: {'p_post_id': postId});
  }

  @override
  Future<void> setCounter(int postId, String column, int value) async {
    await _service.rpc('engagement_update_post_counter', params: {
      'p_post_id': postId,
      'p_column': column,
      'p_value': value,
    });
  }

  @override
  Future<String> uploadMedia(
      Uint8List bytes, String path, String? contentType) async {
    try {
      final bucket = _service.storage.from(StorageBuckets.mintMedia);
      await bucket.uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false));
      return bucket.getPublicUrl(path);
    } on StorageException catch (e) {
      throw ex.ServerException(e.message, code: e.statusCode);
    }
  }

  @override
  Stream<Map<String, dynamic>> watchInserts() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    late final RealtimeChannel channel;
    controller.onListen = () {
      channel = _service.channel('content:posts')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: DbSchemas.content,
          table: DbTables.posts,
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'is_osint',
              value: false),
          callback: (payload) => controller.add(payload.newRecord),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      await _service.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Future<Map<String, dynamic>> editPost(int postId, String body) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(PostRpc.edit,
            params: {'p_post_id': postId, 'p_content': body});
        final row = asRow(res);
        if (row == null) throw const ex.NotFoundException('Post not found.');
        return row;
      });

  @override
  Future<void> deletePost(int postId) => runRpc(() async {
        await _service.rpc<dynamic>(PostRpc.delete, params: {'p_post_id': postId});
      });

  @override
  Future<List<PostEditModel>> fetchEditHistory(int postId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(PostRpc.editHistory,
            params: {'p_post_id': postId});
        return asRows(res).map(PostEditModel.fromJson).toList();
      });
}
