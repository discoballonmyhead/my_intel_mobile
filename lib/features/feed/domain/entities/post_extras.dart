import 'package:equatable/equatable.dart';

/// 'image' | 'video' | 'file' | 'audio', as stored in
/// `content.post_attachments.kind`.
enum AttachmentKind {
  image,
  video,
  file,
  audio;

  static AttachmentKind parse(String? value) => AttachmentKind.values
      .firstWhere((k) => k.name == value, orElse: () => AttachmentKind.file);

  /// Largest upload the backend accepts for this kind (`social_create_post`).
  int get maxBytes => switch (this) {
        AttachmentKind.image => 10 * 1024 * 1024,
        AttachmentKind.video => 100 * 1024 * 1024,
        AttachmentKind.file || AttachmentKind.audio => 20 * 1024 * 1024,
      };
}

/// One row of `content.post_attachments`. A post has at most four.
class PostAttachment extends Equatable {
  const PostAttachment({
    required this.id,
    required this.position,
    required this.kind,
    required this.url,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.durationSeconds,
    this.width,
    this.height,
    this.thumbnailUrl,
  });

  final int id;
  final int position;
  final AttachmentKind kind;
  final String url;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final String? thumbnailUrl;

  @override
  List<Object?> get props => [id, url];
}

class PollOption extends Equatable {
  const PollOption({
    required this.id,
    required this.position,
    required this.label,
    this.votes = 0,
  });

  final int id;
  final int position;
  final String label;
  final int votes;

  @override
  List<Object?> get props => [id, label, votes];
}

/// A post's poll as `poll_get_for_posts` returns it: the counts plus the
/// viewer's own choice. Votes are final.
class PostPoll extends Equatable {
  const PostPoll({
    required this.postId,
    required this.endsAt,
    required this.options,
    this.isClosed = false,
    this.totalVotes = 0,
    this.myOptionId,
  });

  final int postId;
  final DateTime endsAt;
  final List<PollOption> options;
  final bool isClosed;
  final int totalVotes;
  final int? myOptionId;

  bool get hasVoted => myOptionId != null;

  /// Closed by the server, or its end time has passed since it was loaded.
  bool closedAt(DateTime now) => isClosed || !endsAt.isAfter(now);

  @override
  List<Object?> get props => [postId, endsAt, isClosed, totalVotes, myOptionId, options];
}

/// A file already uploaded to `mint-media`, ready to attach to a new post.
class UploadedAttachment {
  const UploadedAttachment({
    required this.kind,
    required this.storagePath,
    required this.url,
    this.fileName,
    this.width,
    this.height,
    this.durationSeconds,
  });

  final AttachmentKind kind;
  final String storagePath;
  final String url;
  final String? fileName;
  final int? width;
  final int? height;
  final double? durationSeconds;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'storage_path': storagePath,
        'url': url,
        if (fileName != null) 'file_name': fileName,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      };
}

/// A poll being written in the composer.
class PollDraft {
  const PollDraft({required this.options, this.durationHours = 24});

  static const int minOptions = 2;
  static const int maxOptions = 4;
  static const int maxLabelLength = 80;

  /// Choices offered in the composer, from 1 hour to the 7-day maximum.
  static const List<int> durationChoices = [1, 6, 24, 72, 168];

  final List<String> options;
  final int durationHours;

  List<String> get cleanOptions =>
      options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();

  bool get isValid =>
      cleanOptions.length >= minOptions &&
      cleanOptions.length <= maxOptions &&
      cleanOptions.every((o) => o.length <= maxLabelLength) &&
      durationHours >= 1 &&
      durationHours <= 168;

  Map<String, dynamic> toJson() =>
      {'options': cleanOptions, 'duration_hours': durationHours};
}
