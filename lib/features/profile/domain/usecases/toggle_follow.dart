import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class ToggleFollow implements UseCase<FollowStats, String> {
  const ToggleFollow(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<FollowStats>> call(String targetUserId) =>
      _repository.toggleFollow(targetUserId);
}

class GetFollowStats implements UseCase<FollowStats, String> {
  const GetFollowStats(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<FollowStats>> call(String targetUserId) =>
      _repository.getFollowStats(targetUserId);
}

class SetFollowingParams {
  const SetFollowingParams({required this.targetUserId, required this.follow});
  final String targetUserId;
  final bool follow;
}

/// Idempotent follow/unfollow — safe against double taps and stale UI state.
class SetFollowing implements UseCase<FollowStats, SetFollowingParams> {
  const SetFollowing(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<FollowStats>> call(SetFollowingParams params) =>
      _repository.setFollowing(params.targetUserId, params.follow);
}

class FollowListParams {
  const FollowListParams({
    required this.profileId,
    required this.kind,
    this.limit = 50,
    this.offset = 0,
  });
  final String profileId;
  final FollowListKind kind;
  final int limit;
  final int offset;
}

class GetFollowList implements UseCase<List<FollowListEntry>, FollowListParams> {
  const GetFollowList(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<List<FollowListEntry>>> call(FollowListParams params) =>
      _repository.getFollowList(
        params.profileId,
        params.kind,
        limit: params.limit,
        offset: params.offset,
      );
}
