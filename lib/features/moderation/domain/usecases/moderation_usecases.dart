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
