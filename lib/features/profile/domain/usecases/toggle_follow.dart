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
