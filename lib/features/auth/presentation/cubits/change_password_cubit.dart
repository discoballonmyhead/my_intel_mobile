import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/change_password.dart';
import '../../domain/usecases/reset_password.dart';

class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.isSubmitting = false,
    this.isChanged = false,
    this.isSendingReset = false,
    this.resetEmailSent = false,
    this.failure,
  });

  final bool isSubmitting;
  final bool isChanged;
  final bool isSendingReset;
  final bool resetEmailSent;
  final Failure? failure;

  ChangePasswordState copyWith({
    bool? isSubmitting,
    bool? isChanged,
    bool? isSendingReset,
    bool? resetEmailSent,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ChangePasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isChanged: isChanged ?? this.isChanged,
      isSendingReset: isSendingReset ?? this.isSendingReset,
      resetEmailSent: resetEmailSent ?? this.resetEmailSent,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props =>
      [isSubmitting, isChanged, isSendingReset, resetEmailSent, failure];
}

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit({
    required String? email,
    required ChangePassword changePassword,
    required SendPasswordReset sendPasswordReset,
  })  : _email = email,
        _changePassword = changePassword,
        _sendPasswordReset = sendPasswordReset,
        super(const ChangePasswordState());

  final String? _email;
  final ChangePassword _changePassword;
  final SendPasswordReset _sendPasswordReset;

  String? get email => _email;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _changePassword(ChangePasswordParams(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
      (_) => emit(state.copyWith(isSubmitting: false, isChanged: true)),
    );
  }

  /// "Forgot your current password?" — emails a reset link instead.
  Future<void> sendResetEmail() async {
    final email = _email;
    if (email == null || state.isSendingReset) return;
    emit(state.copyWith(isSendingReset: true, clearFailure: true));
    final result = await _sendPasswordReset(email);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSendingReset: false, failure: failure)),
      (_) => emit(state.copyWith(isSendingReset: false, resetEmailSent: true)),
    );
  }
}
