import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

/// Holds session state for the whole app. GoRouter listens to this to decide
/// whether a route is reachable, so it must notify on every status change.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required SignIn signIn,
    required SignUp signUp,
    required SignOut signOut,
    required SendPasswordReset sendPasswordReset,
    required UpdatePassword updatePassword,
    required ResendVerification resendVerification,
  })  : _repository = repository,
        _signIn = signIn,
        _signUp = signUp,
        _signOut = signOut,
        _sendPasswordReset = sendPasswordReset,
        _updatePassword = updatePassword,
        _resendVerification = resendVerification {
    _listen();
  }

  final AuthRepository _repository;
  final SignIn _signIn;
  final SignUp _signUp;
  final SignOut _signOut;
  final SendPasswordReset _sendPasswordReset;
  final UpdatePassword _updatePassword;
  final ResendVerification _resendVerification;

  StreamSubscription<AuthUser?>? _userSub;
  StreamSubscription<AuthStatus>? _statusSub;

  AuthUser? _user;
  AuthStatus _status = AuthStatus.unknown;
  bool _busy = false;
  Failure? _failure;

  AuthUser? get user => _user;
  AuthStatus get status => _status;
  bool get busy => _busy;
  Failure? get failure => _failure;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isRecovering => _status == AuthStatus.passwordRecovery;
  bool get isInitialising => _status == AuthStatus.unknown;

  void _listen() {
    _user = _repository.currentUser;
    _status = _user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;

    _userSub = _repository.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });

    // A recovery deep-link produces a session, so this stream is what stops the
    // router dropping the user straight into the feed instead of the reset form.
    _statusSub = _repository.authStatusChanges.listen((status) {
      _status = status;
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    return _run(() => _signIn(SignInParams(email: email, password: password)));
  }

  /// Returns true when the account was created. [needsEmailConfirmation] tells
  /// the page whether to route to the verify screen or straight into the app.
  bool needsEmailConfirmation = false;

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    UserRole role = UserRole.public,
  }) async {
    _setBusy(true);
    final result = await _signUp(SignUpParams(
      email: email,
      password: password,
      username: username,
      role: role,
    ));
    _setBusy(false);

    return result.fold(
      (failure) {
        _failure = failure;
        notifyListeners();
        return false;
      },
      (value) {
        needsEmailConfirmation = value.needsEmailConfirmation;
        _failure = null;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> signOut() async {
    await _signOut(const NoParams());
  }

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _sendPasswordReset(email));

  Future<bool> updatePassword(String password) =>
      _run(() => _updatePassword(password));

  Future<bool> resendVerification(String email) =>
      _run(() => _resendVerification(email));

  void clearError() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  Future<bool> _run(Future<dynamic> Function() action) async {
    _setBusy(true);
    final result = await action();
    _setBusy(false);
    _failure = result.failureOrNull as Failure?;
    notifyListeners();
    return _failure == null;
  }

  void _setBusy(bool value) {
    _busy = value;
    if (value) _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
