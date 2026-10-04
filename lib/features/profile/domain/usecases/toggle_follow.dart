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

/// Ids of everyone the signed-in user follows (drives the Following filter).
class GetFollowedUserIds implements UseCase<List<String>, NoParams> {
  const GetFollowedUserIds(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<List<String>>> call(NoParams params) =>
      _repository.getFollowedUserIds();
}
