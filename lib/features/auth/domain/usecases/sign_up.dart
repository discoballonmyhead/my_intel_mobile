import '../../../../core/constants/user_role.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignUpParams {
  const SignUpParams({
    required this.email,
    required this.password,
    required this.username,
    this.role = UserRole.public,
  });

  final String email;
  final String password;
  final String username;
  final UserRole role;
}

/// Validation lives here, not in the widget, so the same rules apply whatever
/// calls it. `identity.handle_new_user()` reads `username` out of the sign-up
/// metadata to create the profile row, so it must be present and clean.
class SignUp implements UseCase<SignUpResult, SignUpParams> {
  const SignUp(this._repository);

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  final AuthRepository _repository;

  @override
  Future<Result<SignUpResult>> call(SignUpParams params) async {
    final email = params.email.trim();
    final username = params.username.trim();

    if (!email.contains('@')) {
      return const Err(ValidationFailure('Enter a valid email address.'));
    }
    if (!_usernamePattern.hasMatch(username)) {
      return const Err(ValidationFailure(
        'Username must be 3-20 characters, letters, numbers or underscore.',
      ));
    }
    if (params.password.length < 8) {
      return const Err(
        ValidationFailure('Password must be at least 8 characters.'),
      );
    }

    // Only these two roles may be self-assigned; osint is granted by an admin
    // through identity.osint_applications.
    final role = params.role == UserRole.reporter
        ? UserRole.reporter
        : UserRole.public;

    return _repository.signUp(
      email: email,
      password: params.password,
      username: username,
      role: role,
    );
  }
}
