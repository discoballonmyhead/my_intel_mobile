import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

enum ReportTargetType {
  post('post', 'Post'),
  message('message', 'Message'),
  profile('profile', 'Profile'),
  video('video', 'Video'),
  stream('stream', 'Live stream'),
  communityNote('community_note', 'Community note'),
  story('story', 'Story');

  const ReportTargetType(this.value, this.label);
  final String value;
  final String label;

  static ReportTargetType fromValue(String? value) {
    for (final t in ReportTargetType.values) {
      if (t.value == value) return t;
    }
    return ReportTargetType.post;
  }
}

enum ReportReason {
  spam('spam', 'Spam', 'Ads, scams or repetitive junk'),
  harassment('harassment', 'Harassment', 'Targeting or bullying someone'),
  hate('hate', 'Hate', 'Attacks on a protected group'),
  violence('violence', 'Violence', 'Threats or glorified violence'),
  sexual('sexual', 'Sexual content', 'Explicit or unwanted sexual content'),
  misinformation('misinformation', 'Misinformation', 'Fabricated or misleading claims'),
  impersonation('impersonation', 'Impersonation', 'Pretending to be someone else'),
  illegal('illegal', 'Illegal', 'Illegal goods, services or activity'),
  selfHarm('self_harm', 'Self-harm', 'Someone may be at risk'),
  privacy('privacy', 'Privacy', 'Shares private information'),
  other('other', 'Other', 'Something else');

  const ReportReason(this.value, this.label, this.description);
  final String value;
  final String label;
  final String description;

  static ReportReason fromValue(String? value) {
    for (final r in ReportReason.values) {
      if (r.value == value) return r;
    }
    return ReportReason.other;
  }
}

enum ReportStatus {
  open('open', 'OPEN'),
  inReview('in_review', 'IN REVIEW'),
  actioned('actioned', 'ACTIONED'),
  dismissed('dismissed', 'DISMISSED');

  const ReportStatus(this.value, this.label);
  final String value;
  final String label;

  static ReportStatus fromValue(String? value) {
    for (final s in ReportStatus.values) {
      if (s.value == value) return s;
    }
    return ReportStatus.open;
  }

  bool get isPending => this == open || this == inReview;
}

/// Identifies what a report is about. Used as a route key.
class ReportTarget extends Equatable {
  const ReportTarget(this.type, this.id);
  final ReportTargetType type;
  final String id;

  @override
  List<Object?> get props => [type, id];
}

/// Reads the frozen `content_snapshot` jsonb without knowing every table.
class ReportSnapshot {
  const ReportSnapshot(this.raw);
  final Map<String, dynamic>? raw;

  Map<String, dynamic>? get _row {
    final r = raw;
    if (r == null) return null;
    final message = r['message'];
    return message is Map ? Map<String, dynamic>.from(message) : r;
  }

  String? get text {
    final row = _row;
    if (row == null) return null;
    for (final key in ['body', 'content', 'title', 'headline', 'caption', 'username']) {
      final v = row[key];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  String? get mediaUrl {
    final row = _row;
    final v = row?['media_url'] ?? row?['thumbnail_url'] ?? row?['video_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// For reported messages: the preceding lines captured as context.
  List<Map<String, dynamic>> get context {
    final c = raw?['context'];
    if (c is! List) return const [];
    return c.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
}

/// A row of `moderation.reports`.
class Report extends Equatable {
  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reporterId,
    this.reporter,
    this.targetOwnerId,
    this.details,
    this.snapshot = const ReportSnapshot(null),
    this.assignedTo,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionAction,
    this.resolutionNote,
  });

  final int id;
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? reporterId;
  final Profile? reporter;
  final String? targetOwnerId;
  final String? details;
  final ReportSnapshot snapshot;
  final String? assignedTo;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionAction;
  final String? resolutionNote;

  ReportTarget get target => ReportTarget(targetType, targetId);

  @override
  List<Object?> get props => [id, status, assignedTo, resolvedAt, reporter];
}

/// One reported item in the moderator queue, aggregated across reporters.
class ReportQueueItem extends Equatable {
  const ReportQueueItem({
    required this.targetType,
    required this.targetId,
    required this.reportCount,
    required this.reporterCount,
    required this.reasons,
    required this.firstReportedAt,
    required this.lastReportedAt,
    this.targetOwnerId,
    this.owner,
    this.snapshot = const ReportSnapshot(null),
    this.assignedTo,
    this.ownerPriorSanctions = 0,
  });

  final ReportTargetType targetType;
  final String targetId;
  final int reportCount;
  final int reporterCount;
  final List<ReportReason> reasons;
  final DateTime firstReportedAt;
  final DateTime lastReportedAt;
  final String? targetOwnerId;
  final Profile? owner;
  final ReportSnapshot snapshot;
  final String? assignedTo;
  final int ownerPriorSanctions;

  ReportTarget get target => ReportTarget(targetType, targetId);

  @override
  List<Object?> get props =>
      [targetType, targetId, reportCount, assignedTo, lastReportedAt, owner];
}

/// Visibility states on `content.posts.moderation_status`.
enum PostVisibility {
  visible('visible'),
  limited('limited'),
  underReview('under_review'),
  removed('removed');

  const PostVisibility(this.value);
  final String value;

  static PostVisibility fromValue(String? value) {
    for (final v in PostVisibility.values) {
      if (v.value == value) return v;
    }
    return PostVisibility.visible;
  }
}
