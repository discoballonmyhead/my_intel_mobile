import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/reaction.dart';
import '../repositories/reaction_repository.dart';

class GetPostReactions implements UseCase<ReactionSummary, int> {
  const GetPostReactions(this._repository);
  final ReactionRepository _repository;

  @override
  Future<Result<ReactionSummary>> call(int postId) =>
      _repository.getForPost(postId);
}

class GetReactionsForPosts
    implements UseCase<Map<int, ReactionSummary>, List<int>> {
  const GetReactionsForPosts(this._repository);
  final ReactionRepository _repository;

  /// The RPC accepts at most 200 ids per call.
  static const int maxBatch = 200;

  @override
  Future<Result<Map<int, ReactionSummary>>> call(List<int> postIds) async {
    final ids = postIds.toSet().toList();
    if (ids.isEmpty) return const Ok(<int, ReactionSummary>{});
    if (ids.length <= maxBatch) return _repository.getForPosts(ids);

    final merged = <int, ReactionSummary>{};
    for (var i = 0; i < ids.length; i += maxBatch) {
      final end = i + maxBatch > ids.length ? ids.length : i + maxBatch;
      final result = await _repository.getForPosts(ids.sublist(i, end));
      final page = result.valueOrNull;
      if (page == null) return result;
      merged.addAll(page);
    }
    return Ok(merged);
  }
}

class ToggleReactionParams {
  const ToggleReactionParams({required this.postId, required this.type});
  final int postId;
  final ReactionType type;
}

class ToggleReaction implements UseCase<ReactionSummary, ToggleReactionParams> {
  const ToggleReaction(this._repository);
  final ReactionRepository _repository;

  @override
  Future<Result<ReactionSummary>> call(ToggleReactionParams params) =>
      _repository.toggle(params.postId, params.type);
}
