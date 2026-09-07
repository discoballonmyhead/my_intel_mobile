import '../../../../core/utils/result.dart';
import '../entities/video.dart';

abstract interface class MediaRepository {
  /// [type] filters `media.videos.type`, e.g. 'reel'.
  Future<Result<List<Video>>> getVideos({String? type, int limit = 50});

  Future<Result<Video>> uploadVideo({
    required List<int> bytes,
    required String fileExtension,
    String? contentType,
    String? title,
    String? body,
    String type = 'reel',
    String? streamId,
  });

  Future<Result<Video>> toggleVideoLike(Video video);

  Future<Result<void>> incrementViewCount(Video video);

  /// Streams that are live or scheduled, live first.
  Future<Result<List<LiveStream>>> getActiveStreams();

  Future<Result<LiveStream>> createStream({
    required String title,
    String description = '',
  });

  Future<Result<LiveStream>> setStreamStatus(LiveStream stream, LiveStatus status);

  /// Realtime changes on `media.live_streams`.
  Stream<void> watchStreamChanges();
}
