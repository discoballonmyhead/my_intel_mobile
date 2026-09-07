import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../repositories/auth_repository.dart';

/// Sends the recovery email.
class SendPasswordReset implements UseCase<void, String> {
  const SendPasswordReset(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String email) {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return Future.value(
        const Err(ValidationFailure('Enter a valid email address.')),
      );
    }
    return _repository.sendPasswordReset(trimmed);
  }
}

/// Applies the new password once the recovery session is active.
class UpdatePassword implements UseCase<void, String> {
  const UpdatePassword(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String newPassword) {
    if (newPassword.length < 8) {
      return Future.value(
        const Err(ValidationFailure('Password must be at least 8 characters.')),
      );
    }
    return _repository.updatePassword(newPassword);
  }
}

class ResendVerification implements UseCase<void, String> {
  const ResendVerification(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String email) =>
      _repository.resendVerification(email.trim());
}
