import '../../../../core/utils/result.dart';
import '../entities/community_note.dart';

abstract interface class ModerationRepository {
  Future<Result<PostModeration>> getPostModeration(int postId);

  Future<Result<CommunityNote>> submitNote({
    required int postId,
    required String body,
    required NoteStance stance,
  });

  Future<Result<CommunityNote>> updateNote({
    required int noteId,
    required String body,
    required NoteStance stance,
  });

  Future<Result<void>> deleteNote(int noteId);

  Future<Result<void>> rateNote(int noteId, String accuracyRating);

  Future<Result<void>> submitFeedback({
    required Map<String, dynamic> ratings,
    String? overallComment,
  });
}
