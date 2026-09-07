import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';

class OsintApplicationParams {
  const OsintApplicationParams({
    required this.channelName,
    required this.handle,
    this.portfolio,
    this.why,
  });

  final String channelName;
  final String handle;
  final String? portfolio;
  final String? why;
}

class ApplyForOsint implements UseCase<void, OsintApplicationParams> {
  const ApplyForOsint(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<void>> call(OsintApplicationParams params) async {
    if (params.channelName.trim().isEmpty) {
      return const Err(ValidationFailure('Channel name is required.'));
    }
    if (params.handle.trim().isEmpty) {
      return const Err(ValidationFailure('Handle is required.'));
    }
    return _repository.submitOsintApplication(
      channelName: params.channelName.trim(),
      handle: params.handle.trim(),
      portfolio: params.portfolio?.trim(),
      why: params.why?.trim(),
    );
  }
}

class GetMyApplication implements UseCase<OsintApplication?, NoParams> {
  const GetMyApplication(this._repository);

  final ProfileRepository _repository;

  @override
  Future<Result<OsintApplication?>> call(NoParams params) =>
      _repository.getMyApplication();
}
