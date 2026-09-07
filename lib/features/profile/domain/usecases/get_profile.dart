import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class GetProfile implements UseCase<Profile, String> {
  const GetProfile(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(String userId) => _repository.getProfile(userId);
}

/// Used by the channel screen, which is addressed by username rather than id.
class GetProfileByUsername implements UseCase<Profile, String> {
  const GetProfileByUsername(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(String username) =>
      _repository.getProfileByUsername(username);
}
