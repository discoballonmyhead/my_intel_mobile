import '../../../../core/utils/result.dart';
import '../entities/reaction.dart';

abstract interface class ReactionRepository {
  Future<Result<ReactionSummary>> getForPost(int postId);

  /// One round trip for a whole feed page.
  Future<Result<Map<int, ReactionSummary>>> getForPosts(List<int> postIds);

  /// Add, switch or remove the viewer's reaction; returns the new totals.
  Future<Result<ReactionSummary>> toggle(int postId, ReactionType type);
}
