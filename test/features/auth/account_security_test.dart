import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/constants/user_role.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/auth/domain/entities/auth_user.dart';
import 'package:mint/features/auth/domain/repositories/auth_repository.dart';
import 'package:mint/features/auth/domain/usecases/account_security.dart';

class _FakeAuth implements AuthRepository {
  static const password = 'old-password';
  String? updatedPassword;
  String? changedEmail;

  @override
  Future<Result<void>> verifyPassword(String p) async => p == password
      ? const Ok(null)
      : const Err(
          AuthFailure('That email and password do not match an account.'));

  @override
  Future<Result<void>> updatePassword(String p) async {
    updatedPassword = p;
    return const Ok(null);
  }

  @override
  Future<Result<void>> changeEmail(String e) async {
    changedEmail = e;
    return const Ok(null);
  }

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();
  @override
  Stream<AuthStatus> get authStatusChanges => const Stream.empty();
  @override
  AuthUser? get currentUser => null;
  @override
  Future<Result<AuthUser>> signIn(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<Result<SignUpResult>> signUp(
          {required String email,
          required String password,
          required String username,
          UserRole role = UserRole.public}) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> signOut() => throw UnimplementedError();
  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> resendVerification(String email) =>
      throw UnimplementedError();
}

void main() {
  group('ChangePassword', () {
    test('rejects short, mismatched or unchanged passwords before checking',
        () async {
      final auth = _FakeAuth();
      final change = ChangePassword(auth);
      expect(
          (await change(const ChangePasswordParams(
                  current: 'old-password',
                  newPassword: 'short',
                  confirm: 'short')))
              .failureOrNull,
          isA<ValidationFailure>());
      expect(
          (await change(const ChangePasswordParams(
                  current: 'old-password',
                  newPassword: 'new-password',
                  confirm: 'other-one')))
              .failureOrNull,
          isA<ValidationFailure>());
      expect(
          (await change(const ChangePasswordParams(
                  current: 'old-password',
                  newPassword: 'old-password',
                  confirm: 'old-password')))
              .failureOrNull,
          isA<ValidationFailure>());
      expect(auth.updatedPassword, isNull);
    });

    test('a wrong current password is flagged on that field', () async {
      final auth = _FakeAuth();
      final f = (await ChangePassword(auth)(const ChangePasswordParams(
              current: 'nope',
              newPassword: 'new-password',
              confirm: 'new-password')))
          .failureOrNull;
      expect(f?.code, wrongPasswordCode);
      expect(f?.message, 'That password is not right.');
      expect(auth.updatedPassword, isNull);
    });

    test('sets the new password when everything checks out', () async {
      final auth = _FakeAuth();
      final r = await ChangePassword(auth)(const ChangePasswordParams(
          current: 'old-password',
          newPassword: 'new-password',
          confirm: 'new-password'));
      expect(r.failureOrNull, isNull);
      expect(auth.updatedPassword, 'new-password');
    });
  });

  group('ChangeEmail', () {
    test('needs a valid, different address', () async {
      final auth = _FakeAuth();
      final change = ChangeEmail(auth);
      expect(
          (await change(const ChangeEmailParams(
                  currentEmail: 'a@b.co',
                  newEmail: 'not-an-email',
                  password: 'old-password')))
              .failureOrNull,
          isA<ValidationFailure>());
      expect(
          (await change(const ChangeEmailParams(
                  currentEmail: 'a@b.co',
                  newEmail: 'A@B.co',
                  password: 'old-password')))
              .failureOrNull,
          isA<ValidationFailure>());
      expect(auth.changedEmail, isNull);
    });

    test('checks the password, then sends the link', () async {
      final auth = _FakeAuth();
      final wrong = await ChangeEmail(auth)(const ChangeEmailParams(
          currentEmail: 'a@b.co', newEmail: 'new@b.co', password: 'nope'));
      expect(wrong.failureOrNull?.code, wrongPasswordCode);
      final ok = await ChangeEmail(auth)(const ChangeEmailParams(
          currentEmail: 'a@b.co',
          newEmail: ' new@b.co ',
          password: 'old-password'));
      expect(ok.failureOrNull, isNull);
      expect(auth.changedEmail, 'new@b.co');
    });
  });
}
