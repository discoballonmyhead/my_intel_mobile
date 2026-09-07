import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';

abstract interface class MediaRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchVideos({String? type, int limit});
  Future<Map<String, dynamic>> insertVideo(Map<String, dynamic> payload);
  Future<String> uploadVideoFile(Uint8List bytes, String path, String? contentType);
  Future<Set<String>> likedVideoIds();
  Future<void> likeVideo(String videoId);
  Future<void> unlikeVideo(String videoId);
  Future<void> setVideoCounter(String videoId, String column, int value);

  Future<List<Map<String, dynamic>>> fetchActiveStreams();
  Future<Map<String, dynamic>> insertStream(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateStream(String streamId, Map<String, dynamic> payload);

  Stream<void> watchStreamChanges();
}

class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  MediaRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  String get _requireUserId {
    final id = _service.currentUserId;
    if (id == null) throw const ex.AuthException('You must be signed in.');
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchVideos({
    String? type,
    int limit = 50,
  }) async {
    try {
      var query = _service.media.from(DbTables.videos).select();
      if (type != null) query = query.eq('type', type);
      return await query.order('created_at', ascending: false).limit(limit);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> insertVideo(Map<String, dynamic> payload) async {
    try {
      return await _service.media
          .from(DbTables.videos)
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<String> uploadVideoFile(
    Uint8List bytes,
    String path,
    String? contentType,
  ) async {
    try {
      final bucket = _service.storage.from(StorageBuckets.videos);
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );
      return bucket.getPublicUrl(path);
    } on StorageException catch (e) {
      throw ex.ServerException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<Set<String>> likedVideoIds() async {
    final me = _service.currentUserId;
    if (me == null) return <String>{};
    final rows = await _service.media
        .from(DbTables.videoLikes)
        .select('video_id')
        .eq('user_id', me);
    return rows
        .map((r) => r['video_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Future<void> likeVideo(String videoId) async {
    await _service.media
        .from(DbTables.videoLikes)
        .insert({'user_id': _requireUserId, 'video_id': videoId});
  }

  @override
  Future<void> unlikeVideo(String videoId) async {
    await _service.media
        .from(DbTables.videoLikes)
        .delete()
        .eq('user_id', _requireUserId)
        .eq('video_id', videoId);
  }

  @override
  Future<void> setVideoCounter(String videoId, String column, int value) async {
    await _service.media
        .from(DbTables.videos)
        .update({column: value})
        .eq('id', videoId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveStreams() async {
    final rows = await _service.media
        .from(DbTables.liveStreams)
        .select()
        .inFilter('status', ['live', 'scheduled'])
        .order('created_at', ascending: false);

    // 'live' sorts after 'scheduled' alphabetically, so order in Dart instead
    // of relying on the column ordering.
    rows.sort((a, b) {
      final aLive = a['status'] == 'live' ? 0 : 1;
      final bLive = b['status'] == 'live' ? 0 : 1;
      return aLive.compareTo(bLive);
    });
    return rows;
  }

  @override
  Future<Map<String, dynamic>> insertStream(Map<String, dynamic> payload) async {
    try {
      return await _service.media
          .from(DbTables.liveStreams)
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> updateStream(
    String streamId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _service.media
          .from(DbTables.liveStreams)
          .update(payload)
          .eq('id', streamId)
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ex.PermissionException('Only the host can change a stream.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Stream<void> watchStreamChanges() {
    final controller = StreamController<void>.broadcast();
    late final RealtimeChannel channel;

    controller.onListen = () {
      channel = _service.channel('media:live_streams')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.media,
          table: DbTables.liveStreams,
          callback: (_) => controller.add(null),
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
