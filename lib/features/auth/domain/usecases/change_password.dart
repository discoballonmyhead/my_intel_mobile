import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordParams {
  const ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;
}

/// Signed-in password change (Settings → Change password). The reset-email
/// flow for signed-out users stays in [SendPasswordReset] / [UpdatePassword].
class ChangePassword implements UseCase<void, ChangePasswordParams> {
  const ChangePassword(this._repository);

  static const int minLength = 8;

  final AuthRepository _repository;

  /// Shared with the page so the hint text and validation never disagree.
  static String? validateNew(String value) {
    if (value.length < minLength) {
      return 'Use at least $minLength characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  @override
  Future<Result<void>> call(ChangePasswordParams params) async {
    if (params.currentPassword.isEmpty) {
      return const Err(ValidationFailure('Enter your current password.'));
    }
    final problem = validateNew(params.newPassword);
    if (problem != null) return Err(ValidationFailure(problem));
    if (params.newPassword != params.confirmPassword) {
      return const Err(ValidationFailure('The new passwords do not match.'));
    }
    if (params.newPassword == params.currentPassword) {
      return const Err(ValidationFailure(
          'Your new password must be different from the current one.'));
    }
    return _repository.changePassword(
      currentPassword: params.currentPassword,
      newPassword: params.newPassword,
    );
  }
}
