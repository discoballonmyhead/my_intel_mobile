import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/constants/user_role.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/auth_user.dart';
import '../models/auth_user_model.dart';

abstract interface class AuthRemoteDataSource {
  Stream<AuthUserModel?> get authStateChanges;
  Stream<AuthStatus> get authStatusChanges;
  AuthUserModel? get currentUser;

  Future<AuthUserModel> signIn(
      {required String email, required String password});
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required UserRole role,
  });
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> resendVerification(String email);

  /// Signed-in password change: re-verifies [currentPassword] first.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._service);

  final SupabaseService _service;
  static const String _recoveryRedirect = 'io.mint.app://reset-password';
  static const String _emailChangedRedirect = 'io.mint.app://email-changed';

  @override
  Stream<AuthUserModel?> get authStateChanges => _service.auth.onAuthStateChange
      .map((state) => state.session?.user)
      .map((user) => user == null ? null : AuthUserModel.fromSupabase(user));

  @override
  Stream<AuthStatus> get authStatusChanges =>
      _service.auth.onAuthStateChange.map((state) {
        if (state.event == sb.AuthChangeEvent.passwordRecovery) {
          return AuthStatus.passwordRecovery;
        }
        return state.session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated;
      });

  @override
  AuthUserModel? get currentUser {
    final user = _service.auth.currentUser;
    return user == null ? null : AuthUserModel.fromSupabase(user);
  }

  @override
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _service.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const ex.AuthException('Sign in failed. Please try again.');
      }
      return AuthUserModel.fromSupabase(user);
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String username,
    required UserRole role,
  }) async {
    try {
      final response = await _service.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'role': role.value},
      );
      final user = response.user;
      return SignUpResult(
        needsEmailConfirmation: response.session == null,
        user: user == null ? null : AuthUserModel.fromSupabase(user),
      );
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _service.auth.signOut();
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _service.auth
          .resetPasswordForEmail(email, redirectTo: _recoveryRedirect);
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _service.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    try {
      await _service.auth.resend(type: sb.OtpType.signup, email: email);
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _service.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const ex.AuthException('Please sign in again to change your password.');
    }

    // Re-authenticate. This proves the user knows the current password and
    // also satisfies Supabase's "Secure password change" (recent sign-in).
    try {
      await _service.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on sb.AuthException catch (e) {
      throw ex.AuthException('Your current password is incorrect.',
          code: e.statusCode);
    }

    try {
      await _service.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw ex.AuthException(e.message, code: e.statusCode);
    }
  }
}
