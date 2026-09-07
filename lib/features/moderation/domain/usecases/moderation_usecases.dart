import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/community_note.dart';
import '../repositories/moderation_repository.dart';

class GetPostModeration implements UseCase<PostModeration, int> {
  const GetPostModeration(this._repository);

  final ModerationRepository _repository;

  @override
  Future<Result<PostModeration>> call(int postId) =>
      _repository.getPostModeration(postId);
}

class SubmitNoteParams {
  const SubmitNoteParams({
    required this.postId,
    required this.body,
    required this.stance,
  });

  final int postId;
  final String body;
  final NoteStance stance;
}

class SubmitNote implements UseCase<CommunityNote, SubmitNoteParams> {
  const SubmitNote(this._repository);

  static const int minLength = 15;

  final ModerationRepository _repository;

  @override
  Future<Result<CommunityNote>> call(SubmitNoteParams params) async {
    final body = params.body.trim();
    if (body.length < minLength) {
      return const Err(ValidationFailure(
        'A note needs at least 15 characters of context.',
      ));
    }
    return _repository.submitNote(
      postId: params.postId,
      body: body,
      stance: params.stance,
    );
  }
}

class GetOpenClaims implements UseCase<List<Claim>, NoParams> {
  const GetOpenClaims(this._repository);

  final ModerationRepository _repository;

  @override
  Future<Result<List<Claim>>> call(NoParams params) =>
      _repository.getOpenClaims();
}

class ResolveClaimParams {
  const ResolveClaimParams({
    required this.claimId,
    required this.status,
    this.resolutionNote,
  });

  final int claimId;

  /// 'verified' | 'false' | 'reversed'
  final String status;
  final String? resolutionNote;
}

/// Resolving a claim fires `trg_score_on_claim`, which recomputes the author's
/// credibility — so this is a consequential action, not a cosmetic one.
class ResolveClaim implements UseCase<void, ResolveClaimParams> {
  const ResolveClaim(this._repository);

  static const Set<String> validStatuses = {'verified', 'false', 'reversed'};

  final ModerationRepository _repository;

  @override
  Future<Result<void>> call(ResolveClaimParams params) async {
    if (!validStatuses.contains(params.status)) {
      return const Err(ValidationFailure('Unknown resolution status.'));
    }
    return _repository.resolveClaim(
      claimId: params.claimId,
      status: params.status,
      resolutionNote: params.resolutionNote,
    );
  }
}

class SubmitFeedbackParams {
  const SubmitFeedbackParams({required this.ratings, this.comment});
  final Map<String, dynamic> ratings;
  final String? comment;
}

class SubmitFeedback implements UseCase<void, SubmitFeedbackParams> {
  const SubmitFeedback(this._repository);

  final ModerationRepository _repository;

  @override
  Future<Result<void>> call(SubmitFeedbackParams params) async {
    if (params.ratings.isEmpty) {
      return const Err(ValidationFailure('Rate at least one item.'));
    }
    return _repository.submitFeedback(
      ratings: params.ratings,
      overallComment: params.comment,
    );
  }
}
