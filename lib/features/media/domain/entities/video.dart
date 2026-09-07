import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

/// A row of `media.videos`.
class Video extends Equatable {
  const Video({
    required this.id,
    required this.videoUrl,
    this.authorId,
    this.author,
    this.title,
    this.body,
    this.thumbnailUrl,
    this.durationSeconds,
    this.type = 'reel',
    this.viewCount = 0,
    this.likes = 0,
    this.streamId,
    this.createdAt,
    this.likedByMe = false,
  });

  final String id;
  final String videoUrl;
  final String? authorId;
  final Profile? author;
  final String? title;
  final String? body;
  final String? thumbnailUrl;
  final int? durationSeconds;

  /// 'reel' | 'clip' | recording of a stream
  final String type;
  final int viewCount;
  final int likes;
  final String? streamId;
  final DateTime? createdAt;

  final bool likedByMe;

  bool get isFromStream => streamId != null;

  Video copyWith({int? likes, bool? likedByMe, int? viewCount}) {
    return Video(
      id: id,
      videoUrl: videoUrl,
      authorId: authorId,
      author: author,
      title: title,
      body: body,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      type: type,
      viewCount: viewCount ?? this.viewCount,
      likes: likes ?? this.likes,
      streamId: streamId,
      createdAt: createdAt,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  @override
  List<Object?> get props => [id, likes, viewCount, likedByMe];
}

/// A row of `media.live_streams`.
class LiveStream extends Equatable {
  const LiveStream({
    required this.id,
    required this.title,
    this.hostId,
    this.host,
    this.description,
    this.status = LiveStatus.scheduled,
    this.viewerCount = 0,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? hostId;
  final Profile? host;
  final String? description;
  final LiveStatus status;
  final int viewerCount;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  bool get isLive => status == LiveStatus.live;

  @override
  List<Object?> get props => [id, status, viewerCount];
}

enum LiveStatus {
  scheduled('scheduled'),
  live('live'),
  ended('ended');

  const LiveStatus(this.value);
  final String value;

  static LiveStatus fromValue(String? value) => switch (value) {
        'live' => LiveStatus.live,
        'ended' => LiveStatus.ended,
        _ => LiveStatus.scheduled,
      };
}
