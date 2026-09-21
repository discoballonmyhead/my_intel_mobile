import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';

abstract interface class MediaRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchVideos({String? type, int limit});
  Future<Map<String, dynamic>> insertVideo(Map<String, dynamic> payload);
  Future<String> uploadVideoFile(
      Uint8List bytes, String path, String? contentType);
  Future<Set<String>> likedVideoIds();
  Future<void> likeVideo(String videoId);
  Future<void> unlikeVideo(String videoId);
  Future<void> setVideoCounter(String videoId, String column, int value);
  Future<List<Map<String, dynamic>>> fetchActiveStreams();
  Future<Map<String, dynamic>> insertStream(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateStream(
      String streamId, Map<String, dynamic> payload);
  Stream<void> watchStreamChanges();
}

class MediaRemoteDataSourceImpl implements MediaRemoteDataSource {
  MediaRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> fetchVideos(
      {String? type, int limit = 50}) async {
    try {
      final res =
          await _service.rpc<List<dynamic>>('media_get_videos', params: {
        'p_type': type,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> insertVideo(Map<String, dynamic> payload) async {
    try {
      final res = await _service
          .rpc('media_create_video', params: {'p_payload': payload});
      return res as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<String> uploadVideoFile(
      Uint8List bytes, String path, String? contentType) async {
    try {
      final bucket = _service.storage.from(StorageBuckets.videos);
      await bucket.uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: contentType));
      return bucket.getPublicUrl(path);
    } on StorageException catch (e) {
      throw ex.ServerException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<Set<String>> likedVideoIds() async {
    final res =
        await _service.rpc<List<dynamic>>('engagement_get_liked_video_ids');
    return res?.map((e) => e as String).toSet() ?? <String>{};
  }

  @override
  Future<void> likeVideo(String videoId) async {
    await _service
        .rpc('engagement_like_video', params: {'p_video_id': videoId});
  }

  @override
  Future<void> unlikeVideo(String videoId) async {
    await _service
        .rpc('engagement_unlike_video', params: {'p_video_id': videoId});
  }

  @override
  Future<void> setVideoCounter(String videoId, String column, int value) async {
    await _service.rpc('engagement_update_video_counter', params: {
      'p_video_id': videoId,
      'p_column': column,
      'p_value': value,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveStreams() async {
    final res = await _service.rpc<List<dynamic>>('stream_get_active');
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<Map<String, dynamic>> insertStream(
      Map<String, dynamic> payload) async {
    try {
      final res = await _service.rpc('stream_create', params: {
        'p_title': payload['title'],
        'p_description': payload['description']
      });
      return {'id': res, ...payload};
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> updateStream(
      String streamId, Map<String, dynamic> payload) async {
    try {
      final res = await _service.rpc('stream_update_status',
          params: {'p_stream_id': streamId, 'p_payload': payload});
      return res as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      if (e.code == '42501')
        throw const ex.PermissionException(
            'Only the host can change a stream.');
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
