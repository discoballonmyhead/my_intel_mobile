import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/video.dart';

class VideoModel extends Video {
  const VideoModel({
    required super.id,
    required super.videoUrl,
    super.authorId,
    super.author,
    super.title,
    super.body,
    super.thumbnailUrl,
    super.durationSeconds,
    super.type,
    super.viewCount,
    super.likes,
    super.streamId,
    super.createdAt,
    super.likedByMe,
  });

  factory VideoModel.fromJson(
    Map<String, dynamic> json, {
    Profile? author,
    bool likedByMe = false,
  }) {
    return VideoModel(
      id: json['id'] as String,
      videoUrl: (json['video_url'] as String?) ?? '',
      authorId: json['author_id'] as String?,
      author: author,
      title: json['title'] as String?,
      body: json['body'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      type: (json['type'] as String?) ?? 'reel',
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      streamId: json['stream_id'] as String?,
      createdAt: parseTimestamp(json['created_at']),
      likedByMe: likedByMe,
    );
  }

  static Map<String, dynamic> toInsertJson({
    required String authorId,
    required String videoUrl,
    String? title,
    String? body,
    String type = 'reel',
    String? streamId,
  }) {
    return {
      'author_id': authorId,
      'video_url': videoUrl,
      'title': title ?? '',
      'body': body ?? '',
      'type': type,
      'stream_id': streamId,
    };
  }
}

class LiveStreamModel extends LiveStream {
  const LiveStreamModel({
    required super.id,
    required super.title,
    super.hostId,
    super.host,
    super.description,
    super.status,
    super.viewerCount,
    super.startedAt,
    super.endedAt,
    super.createdAt,
  });

  factory LiveStreamModel.fromJson(
    Map<String, dynamic> json, {
    Profile? host,
  }) {
    return LiveStreamModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      hostId: json['host_id'] as String?,
      host: host,
      description: json['description'] as String?,
      status: LiveStatus.fromValue(json['status'] as String?),
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      startedAt: parseTimestamp(json['started_at']),
      endedAt: parseTimestamp(json['ended_at']),
      createdAt: parseTimestamp(json['created_at']),
    );
  }
}
