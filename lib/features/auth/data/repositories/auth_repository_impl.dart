import 'dart:async';

import '../../../../core/constants/user_role.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Turns data-source exceptions into domain failures. This is the only place
/// in the auth feature where a `try` block appears.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Stream<AuthUser?> get authStateChanges => _remote.authStateChanges;

  @override
  Stream<AuthStatus> get authStatusChanges => _remote.authStatusChanges;

  @override
  AuthUser? get currentUser => _remote.currentUser;

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() => _remote.signIn(email: email, password: password));

  @override
  Future<Result<SignUpResult>> signUp({
    required String email,
    required String password,
    required String username,
    UserRole role = UserRole.public,
  }) =>
      _guard(() => _remote.signUp(
            email: email,
            password: password,
            username: username,
            role: role,
          ));

  @override
  Future<Result<void>> signOut() => _guard(_remote.signOut);

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      _guard(() => _remote.sendPasswordReset(email));

  @override
  Future<Result<void>> updatePassword(String newPassword) =>
      _guard(() => _remote.updatePassword(newPassword));

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _guard(() => _remote.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          ));

  @override
  Future<Result<void>> resendVerification(String email) =>
      _guard(() => _remote.resendVerification(email));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on ex.AuthException catch (e) {
      return Err(AuthFailure(_humanise(e.message), code: e.code));
    } on ex.ServerException catch (e) {
      return Err(ServerFailure(e.message, code: e.code));
    } on TimeoutException {
      return const Err(NetworkFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  /// Supabase's raw auth strings are terse; these are the ones users actually
  /// hit, rewritten so the UI can show them verbatim.
  String _humanise(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'That email and password do not match an account.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirm your email address before signing in.';
    }
    if (lower.contains('already registered')) {
      return 'An account with that email already exists.';
    }
    if (lower.contains('different from the old password')) {
      return 'Your new password must be different from the current one.';
    }
    if (lower.contains('password should be') || lower.contains('weak password')) {
      return 'That password is too weak. Use at least 8 characters with a mix '
          'of letters and numbers.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    return message;
  }
}
