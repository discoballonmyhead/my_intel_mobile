import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileParams {
  const UpdateProfileParams({required this.userId, this.username});
  final String userId;
  final String? username;
}

class UpdateProfile implements UseCase<Profile, UpdateProfileParams> {
  const UpdateProfile(this._repository);

  static final RegExp _pattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  final ProfileRepository _repository;

  @override
  Future<Result<Profile>> call(UpdateProfileParams params) async {
    final username = params.username?.trim();
    if (username != null && !_pattern.hasMatch(username)) {
      return const Err(ValidationFailure(
        'Username must be 3-20 characters, letters, numbers or underscore.',
      ));
    }
    return _repository.updateProfile(params.userId, username: username);
  }
}
