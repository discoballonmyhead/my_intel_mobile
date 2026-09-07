import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/community_note.dart';
import '../../domain/repositories/moderation_repository.dart';
import '../datasources/moderation_remote_data_source.dart';
import '../models/community_note_model.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  ModerationRepositoryImpl(this._remote, this._profiles, this._service);

  final ModerationRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;
  final SupabaseService _service;

  @override
  Future<Result<PostModeration>> getPostModeration(int postId) {
    return guard(() async {
      final claimRow = await _remote.fetchClaimForPost(postId);
      final noteRows = await _remote.fetchNotesForPost(postId);
      final authors = await _profiles
          .profilesByIds(noteRows.map((r) => r['author_id'] as String?));

      final notes = noteRows
          .map((row) => CommunityNoteModel.fromJson(
                row,
                author: authors[row['author_id']],
              ) as CommunityNote)
          .toList();

      final me = _service.currentUserId;
      CommunityNote? myNote;
      for (final note in notes) {
        if (note.authorId == me) {
          myNote = note;
          break;
        }
      }

      return PostModeration(
        claim: claimRow == null ? null : ClaimModel.fromJson(claimRow),
        notes: notes,
        myNote: myNote,
      );
    });
  }

  @override
  Future<Result<CommunityNote>> submitNote({
    required int postId,
    required String body,
    required NoteStance stance,
  }) {
    return guard(() async {
      final userId = _service.currentUserId;
      if (userId == null) {
        throw const ex.AuthException('Sign in to add a note.');
      }
      final row = await _remote.insertNote(CommunityNoteModel.toInsertJson(
        postId: postId,
        authorId: userId,
        body: body.trim(),
        stance: stance,
      ));
      final authors = await _profiles.profilesByIds([userId]);
      return CommunityNoteModel.fromJson(row, author: authors[userId]);
    });
  }

  @override
  Future<Result<CommunityNote>> updateNote({
    required int noteId,
    required String body,
    required NoteStance stance,
  }) {
    return guard(() async {
      final row = await _remote.updateNote(noteId, {
        'body': body.trim(),
        'stance': stance.value,
      });
      final authorId = row['author_id'] as String?;
      final authors = await _profiles.profilesByIds([authorId]);
      return CommunityNoteModel.fromJson(row, author: authors[authorId]);
    });
  }

  @override
  Future<Result<void>> deleteNote(int noteId) =>
      guard(() => _remote.deleteNote(noteId));

  @override
  Future<Result<List<Claim>>> getOpenClaims() {
    return guard(() async {
      final rows = await _remote.fetchOpenClaims();
      return rows.map((row) => ClaimModel.fromJson(row) as Claim).toList();
    });
  }

  @override
  Future<Result<void>> resolveClaim({
    required int claimId,
    required String status,
    String? resolutionNote,
  }) {
    return guard(() => _remote.updateClaim(claimId, {
          'status': status,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          'resolution_note': resolutionNote,
        }));
  }

  @override
  Future<Result<void>> rateNote(int noteId, String accuracyRating) =>
      guard(() => _remote.rateNote(noteId, accuracyRating));

  @override
  Future<Result<void>> submitFeedback({
    required Map<String, dynamic> ratings,
    String? overallComment,
  }) {
    return guard(() => _remote.insertFeedback({
          'ratings': ratings,
          'overall_comment': overallComment,
        }));
  }
}
