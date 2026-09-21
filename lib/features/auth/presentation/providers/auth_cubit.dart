import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/core/utils/result.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/reset_password.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.failure,
    this.needsEmailConfirmation = false,
  });

  final AuthUser? user;
  final AuthStatus status;
  final bool isLoading;
  final Failure? failure;
  final bool needsEmailConfirmation;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isRecovering => status == AuthStatus.passwordRecovery;
  bool get isInitialising => status == AuthStatus.unknown;

  AuthState copyWith({
    AuthUser? user,
    AuthStatus? status,
    bool? isLoading,
    Failure? failure,
    bool? needsEmailConfirmation,
    bool clearFailure = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      needsEmailConfirmation:
          needsEmailConfirmation ?? this.needsEmailConfirmation,
    );
  }

  @override
  List<Object?> get props =>
      [user, status, isLoading, failure, needsEmailConfirmation];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
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
        _resendVerification = resendVerification,
        super(AuthState(
          user: repository.currentUser,
          status: repository.currentUser == null
              ? AuthStatus.unauthenticated
              : AuthStatus.authenticated,
        )) {
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

  void _listen() {
    _userSub = _repository.authStateChanges.listen((user) {
      emit(state.copyWith(user: user));
    });

    _statusSub = _repository.authStatusChanges.listen((status) {
      emit(state.copyWith(status: status));
    });
  }

  Future<bool> signIn(String email, String password) async {
    return _run(() => _signIn(SignInParams(email: email, password: password)));
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    UserRole role = UserRole.public,
  }) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _signUp(SignUpParams(
      email: email,
      password: password,
      username: username,
      role: role,
    ));

    return result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, failure: failure));
        return false;
      },
      (value) {
        emit(state.copyWith(
          isLoading: false,
          needsEmailConfirmation: value.needsEmailConfirmation,
        ));
        return true;
      },
    );
  }

  Future<void> signOut() async => await _signOut(const NoParams());

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _sendPasswordReset(email));
  Future<bool> updatePassword(String password) =>
      _run(() => _updatePassword(password));
  Future<bool> resendVerification(String email) =>
      _run(() => _resendVerification(email));

  void clearError() {
    if (state.failure != null) {
      emit(state.copyWith(clearFailure: true));
    }
  }

  Future<bool> _run(Future<Result<dynamic>> Function() action) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await action();

    return result.fold((failure) {
      emit(state.copyWith(isLoading: false, failure: failure));
      return false;
    }, (_) {
      emit(state.copyWith(isLoading: false));
      return true;
    });
  }

  @override
  Future<void> close() {
    _userSub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }
}
