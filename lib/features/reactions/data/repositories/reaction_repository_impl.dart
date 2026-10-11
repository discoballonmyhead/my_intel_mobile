import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/reaction.dart';
import '../../domain/repositories/reaction_repository.dart';
import '../datasources/reaction_remote_data_source.dart';

class ReactionRepositoryImpl implements ReactionRepository {
  ReactionRepositoryImpl(this._remote);
  final ReactionRemoteDataSource _remote;

  @override
  Future<Result<ReactionSummary>> getForPost(int postId) =>
      guard(() => _remote.fetchForPost(postId));

  @override
  Future<Result<Map<int, ReactionSummary>>> getForPosts(List<int> postIds) =>
      guard(() async {
        final rows = await _remote.fetchForPosts(postIds);
        return {for (final r in rows) r.postId: r};
      });

  @override
  Future<Result<ReactionSummary>> toggle(int postId, ReactionType type) =>
      guard(() => _remote.toggle(postId, type.value));
}
