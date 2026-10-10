import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../repositories/auth_repository.dart';

/// Shown on the current-password field when it doesn't match.
const wrongPasswordCode = 'wrong_password';

/// Confirms [password] is the signed-in user's, turning a sign-in failure into
/// a field-level "That password is not right."
Future<Result<void>> _confirm(AuthRepository repository, String password) async {
  if (password.isEmpty) {
    return const Err(
        AuthFailure('Enter your current password.', code: wrongPasswordCode));
  }
  final result = await repository.verifyPassword(password);
  final failure = result.failureOrNull;
  if (failure is AuthFailure) {
    return const Err(
        AuthFailure('That password is not right.', code: wrongPasswordCode));
  }
  return result;
}

class ChangePasswordParams {
  const ChangePasswordParams({
    required this.current,
    required this.newPassword,
    required this.confirm,
  });

  final String current;
  final String newPassword;
  final String confirm;
}

/// Checks the current password, then sets the new one.
class ChangePassword implements UseCase<void, ChangePasswordParams> {
  const ChangePassword(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(ChangePasswordParams params) async {
    if (params.newPassword.length < 8) {
      return const Err(
          ValidationFailure('Your new password needs at least 8 characters.'));
    }
    if (params.newPassword != params.confirm) {
      return const Err(ValidationFailure('The new passwords don’t match.'));
    }
    if (params.newPassword == params.current) {
      return const Err(
          ValidationFailure('Choose a password you haven’t used here.'));
    }
    final confirmed = await _confirm(_repository, params.current);
    if (confirmed.failureOrNull case final failure?) return Err(failure);
    return _repository.updatePassword(params.newPassword);
  }
}

class ChangeEmailParams {
  const ChangeEmailParams({
    required this.currentEmail,
    required this.newEmail,
    required this.password,
  });

  final String currentEmail;
  final String newEmail;
  final String password;
}

/// Checks the password, then asks Supabase to email a confirmation link.
class ChangeEmail implements UseCase<void, ChangeEmailParams> {
  const ChangeEmail(this._repository);

  final AuthRepository _repository;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Future<Result<void>> call(ChangeEmailParams params) async {
    final email = params.newEmail.trim();
    if (!_email.hasMatch(email)) {
      return const Err(ValidationFailure('Enter a valid email address.'));
    }
    if (email.toLowerCase() == params.currentEmail.toLowerCase()) {
      return const Err(ValidationFailure('That is already your email.'));
    }
    final confirmed = await _confirm(_repository, params.password);
    if (confirmed.failureOrNull case final failure?) return Err(failure);
    return _repository.changeEmail(email);
  }
}
