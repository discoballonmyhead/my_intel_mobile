import 'dart:typed_data';

import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/video.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_remote_data_source.dart';
import '../models/video_model.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._remote, this._profiles, this._service);

  final MediaRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;
  final SupabaseService _service;

  @override
  Future<Result<List<Video>>> getVideos({String? type, int limit = 50}) {
    return guard(() async {
      final rows = await _remote.fetchVideos(type: type, limit: limit);
      final liked = await _remote.likedVideoIds();
      final authors =
          await _profiles.profilesByIds(rows.map((r) => r['author_id'] as String?));

      return rows
          .map((row) => VideoModel.fromJson(
                row,
                author: authors[row['author_id']],
                likedByMe: liked.contains(row['id']),
              ) as Video)
          .toList();
    });
  }

  @override
  Future<Result<Video>> uploadVideo({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
    String? title,
    String? body,
    String type = 'reel',
    String? streamId,
  }) {
    return guard(() async {
      final userId = _service.currentUserId;
      if (userId == null) {
        throw const ex.AuthException('Sign in to upload.');
      }

      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final publicUrl = await _remote.uploadVideoFile(
        Uint8List.fromList(bytes),
        path,
        contentType,
      );

      final row = await _remote.insertVideo(VideoModel.toInsertJson(
        authorId: userId,
        videoUrl: publicUrl,
        title: title,
        body: body,
        type: type,
        streamId: streamId,
      ));

      final authors = await _profiles.profilesByIds([userId]);
      return VideoModel.fromJson(row, author: authors[userId]);
    });
  }

  @override
  Future<Result<Video>> toggleVideoLike(Video video) {
    return guard(() async {
      final nextLiked = !video.likedByMe;
      final nextCount =
          nextLiked ? video.likes + 1 : (video.likes - 1).clamp(0, 1 << 30);

      if (nextLiked) {
        await _remote.likeVideo(video.id);
      } else {
        await _remote.unlikeVideo(video.id);
      }
      await _remote.setVideoCounter(video.id, 'likes', nextCount);

      return video.copyWith(likedByMe: nextLiked, likes: nextCount);
    });
  }

  @override
  Future<Result<void>> incrementViewCount(Video video) {
    return guard(() => _remote.setVideoCounter(
          video.id,
          'view_count',
          video.viewCount + 1,
        ));
  }

  @override
  Future<Result<List<LiveStream>>> getActiveStreams() {
    return guard(() async {
      final rows = await _remote.fetchActiveStreams();
      final hosts =
          await _profiles.profilesByIds(rows.map((r) => r['host_id'] as String?));
      return rows
          .map((row) =>
              LiveStreamModel.fromJson(row, host: hosts[row['host_id']])
                  as LiveStream)
          .toList();
    });
  }

  @override
  Future<Result<LiveStream>> createStream({
    required String title,
    String description = '',
  }) {
    return guard(() async {
      final userId = _service.currentUserId;
      if (userId == null) {
        throw const ex.AuthException('Sign in to go live.');
      }
      final row = await _remote.insertStream({
        'host_id': userId,
        'title': title,
        'description': description,
        'status': LiveStatus.scheduled.value,
      });
      final hosts = await _profiles.profilesByIds([userId]);
      return LiveStreamModel.fromJson(row, host: hosts[userId]);
    });
  }

  @override
  Future<Result<LiveStream>> setStreamStatus(
    LiveStream stream,
    LiveStatus status,
  ) {
    return guard(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final row = await _remote.updateStream(stream.id, {
        'status': status.value,
        if (status == LiveStatus.live) 'started_at': now,
        if (status == LiveStatus.ended) 'ended_at': now,
      });
      return LiveStreamModel.fromJson(row, host: stream.host);
    });
  }

  @override
  Stream<void> watchStreamChanges() => _remote.watchStreamChanges();
}
