import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/community_note.dart';

class CommunityNoteModel extends CommunityNote {
  const CommunityNoteModel({
    required super.id,
    required super.postId,
    required super.body,
    required super.stance,
    super.authorId,
    super.author,
    super.accuracyRating,
    super.weight,
    super.createdAt,
  });

  factory CommunityNoteModel.fromJson(
    Map<String, dynamic> json, {
    Profile? author,
  }) {
    return CommunityNoteModel(
      id: (json['id'] as num).toInt(),
      postId: (json['post_id'] as num?)?.toInt() ?? 0,
      body: (json['body'] as String?) ?? '',
      stance: NoteStance.fromValue(json['stance'] as String?),
      authorId: json['author_id'] as String?,
      author: author,
      accuracyRating: json['accuracy_rating'] as String?,
      weight: (json['weight'] as num?)?.toInt() ?? 1,
      createdAt: parseTimestamp(json['created_at']),
    );
  }

  /// `weight` is intentionally omitted — the `trg_note_weight` trigger sets it
  /// from the author's role, and sending it from the client would be ignored
  /// at best and misleading at worst.
  static Map<String, dynamic> toInsertJson({
    required int postId,
    required String authorId,
    required String body,
    required NoteStance stance,
  }) {
    return {
      'post_id': postId,
      'author_id': authorId,
      'body': body,
      'stance': stance.value,
    };
  }
}

class ClaimModel extends Claim {
  const ClaimModel({
    required super.id,
    required super.postId,
    super.status,
    super.resolvedBy,
    super.resolvedAt,
    super.resolutionNote,
    super.createdAt,
  });

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    return ClaimModel(
      id: (json['id'] as num).toInt(),
      postId: (json['post_id'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'open',
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: parseTimestamp(json['resolved_at']),
      resolutionNote: json['resolution_note'] as String?,
      createdAt: parseTimestamp(json['created_at']),
    );
  }
}
