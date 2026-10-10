import '../../../../core/utils/date_x.dart';
import '../../domain/entities/post_extras.dart';

/// Parsers for the attachment and poll payloads returned by
/// `attachment_get_for_posts`, `poll_get_for_posts`, `poll_vote` and
/// `social_create_post`.
class PostExtrasModel {
  const PostExtrasModel._();

  static List<PostAttachment> attachmentsFromJson(Object? json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((m) => attachmentFromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  static PostAttachment attachmentFromJson(Map<String, dynamic> json) {
    return PostAttachment(
      id: (json['id'] as num).toInt(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      kind: AttachmentKind.parse(json['kind'] as String?),
      url: json['url'] as String,
      fileName: json['file_name'] as String?,
      mimeType: json['mime_type'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  static PostPoll? pollFromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final options = (map['options'] as List? ?? const [])
        .whereType<Map>()
        .map((o) => PollOption(
              id: (o['id'] as num).toInt(),
              position: (o['position'] as num?)?.toInt() ?? 0,
              label: (o['label'] as String?) ?? '',
              votes: (o['votes'] as num?)?.toInt() ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return PostPoll(
      postId: (map['post_id'] as num).toInt(),
      endsAt: parseTimestamp(map['ends_at']) ?? DateTime.now().toUtc(),
      isClosed: (map['is_closed'] as bool?) ?? false,
      totalVotes: (map['total_votes'] as num?)?.toInt() ?? 0,
      myOptionId: (map['my_option_id'] as num?)?.toInt(),
      options: options,
    );
  }
}
