import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInParams {
  const SignInParams({required this.email, required this.password});
  final String email;
  final String password;
}

class SignIn implements UseCase<AuthUser, SignInParams> {
  const SignIn(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthUser>> call(SignInParams params) async {
    final email = params.email.trim();
    if (!email.contains('@')) {
      return const Err(ValidationFailure('Enter a valid email address.'));
    }
    if (params.password.isEmpty) {
      return const Err(ValidationFailure('Enter your password.'));
    }
    return _repository.signIn(email: email, password: params.password);
  }
}
