import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../models/post_model.dart';

abstract interface class PostRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchPosts({int limit});
  Future<Map<String, dynamic>?> fetchPost(int postId);
  Future<List<Map<String, dynamic>>> fetchPostsByIds(List<int> ids);
  Future<List<Map<String, dynamic>>> fetchPostsByAuthor(String authorId, {int limit});
  Future<List<RepostRow>> fetchRecentReposts({int limit});

  /// Ids of the posts the current user has liked / saved / reposted.
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

  /// The counter columns are updated from the client because there is no
  /// database trigger maintaining them.
  Future<void> setCounter(int postId, String column, int value);

  Future<String> uploadMedia(Uint8List bytes, String path, String? contentType);

  Stream<Map<String, dynamic>> watchInserts();
}

class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  PostRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  String get _requireUserId {
    final id = _service.currentUserId;
    if (id == null) throw const ex.AuthException('You must be signed in.');
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPosts({int limit = 50}) async {
    try {
      final rows = await _service.content
          .from(DbTables.posts)
          .select()
          .eq('is_osint', false)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows;
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchPost(int postId) async {
    try {
      return await _service.content
          .from(DbTables.posts)
          .select()
          .eq('id', postId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPostsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _service.content
        .from(DbTables.posts)
        .select()
        .inFilter('id', ids);
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPostsByAuthor(
    String authorId, {
    int limit = 20,
  }) async {
    final rows = await _service.content
        .from(DbTables.posts)
        .select()
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows;
  }

  @override
  Future<List<RepostRow>> fetchRecentReposts({int limit = 50}) async {
    final rows = await _service.content
        .from(DbTables.reposts)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(RepostRow.fromJson).toList();
  }

  @override
  Future<Set<int>> likedPostIds() => _ownPostIds(DbTables.likes);

  @override
  Future<Set<int>> savedPostIds() => _ownPostIds(DbTables.savedPosts);

  @override
  Future<Set<int>> repostedPostIds() => _ownPostIds(DbTables.reposts);

  Future<Set<int>> _ownPostIds(String table) async {
    final me = _service.currentUserId;
    if (me == null) return <int>{};
    final rows = await _service.content
        .from(table)
        .select('post_id')
        .eq('user_id', me);
    return rows
        .map((r) => (r['post_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
  }

  @override
  Future<List<int>> savedPostIdsOrdered() async {
    final rows = await _service.content
        .from(DbTables.savedPosts)
        .select('post_id, created_at')
        .eq('user_id', _requireUserId)
        .order('created_at', ascending: false);
    return rows
        .map((r) => (r['post_id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  @override
  Future<Map<String, dynamic>> insertPost(Map<String, dynamic> payload) async {
    try {
      return await _service.content
          .from(DbTables.posts)
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ex.PermissionException(
          'You do not have permission to publish that.',
        );
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> like(int postId) async {
    await _service.content
        .from(DbTables.likes)
        .insert({'user_id': _requireUserId, 'post_id': postId});
  }

  @override
  Future<void> unlike(int postId) async {
    await _service.content
        .from(DbTables.likes)
        .delete()
        .eq('user_id', _requireUserId)
        .eq('post_id', postId);
  }

  @override
  Future<void> save(int postId) async {
    await _service.content
        .from(DbTables.savedPosts)
        .insert({'user_id': _requireUserId, 'post_id': postId});
  }

  @override
  Future<void> unsave(int postId) async {
    await _service.content
        .from(DbTables.savedPosts)
        .delete()
        .eq('user_id', _requireUserId)
        .eq('post_id', postId);
  }

  @override
  Future<void> repost(int postId, {String? quote}) async {
    await _service.content.from(DbTables.reposts).insert({
      'user_id': _requireUserId,
      'post_id': postId,
      'quote_body': quote,
    });
  }

  @override
  Future<void> undoRepost(int postId) async {
    await _service.content
        .from(DbTables.reposts)
        .delete()
        .eq('user_id', _requireUserId)
        .eq('post_id', postId);
  }

  @override
  Future<void> setCounter(int postId, String column, int value) async {
    await _service.content
        .from(DbTables.posts)
        .update({column: value})
        .eq('id', postId);
  }

  @override
  Future<String> uploadMedia(
    Uint8List bytes,
    String path,
    String? contentType,
  ) async {
    try {
      final bucket = _service.storage.from(StorageBuckets.mintMedia);
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
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
            value: false,
          ),
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
}
