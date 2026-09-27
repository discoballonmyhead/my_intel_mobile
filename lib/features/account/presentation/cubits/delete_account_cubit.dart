import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../domain/usecases/account_usecases.dart';

class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.confirmation = '',
    this.isSubmitting = false,
    this.isDeleted = false,
    this.failure,
  });

  final String confirmation;
  final bool isSubmitting;
  final bool isDeleted;
  final Failure? failure;

  bool get canSubmit =>
      !isSubmitting && confirmation.trim() == AccountRpc.deleteConfirmation;

  DeleteAccountState copyWith({
    String? confirmation,
    bool? isSubmitting,
    bool? isDeleted,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return DeleteAccountState(
      confirmation: confirmation ?? this.confirmation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDeleted: isDeleted ?? this.isDeleted,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [confirmation, isSubmitting, isDeleted, failure];
}

class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  DeleteAccountCubit({
    required DeleteMyAccount deleteMyAccount,
    required SignOut signOut,
  })  : _deleteMyAccount = deleteMyAccount,
        _signOut = signOut,
        super(const DeleteAccountState());

  final DeleteMyAccount _deleteMyAccount;
  final SignOut _signOut;

  void updateConfirmation(String value) =>
      emit(state.copyWith(confirmation: value, clearFailure: true));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _deleteMyAccount(state.confirmation);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(isSubmitting: false, failure: failure));
      return;
    }

    // The account is gone; drop the local session. The router's auth guard
    // then sends the user to /login on its own.
    await _signOut(const NoParams());
    if (!isClosed) emit(state.copyWith(isSubmitting: false, isDeleted: true));
  }
}
