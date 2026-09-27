import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../../moderation/domain/usecases/report_usecases.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/usecases/admin_usecases.dart';

class AdminUserDetailState extends Equatable {
  const AdminUserDetailState({
    required this.userId,
    this.detail,
    this.isLoading = true,
    this.isBusy = false,
    this.failure,
    this.actionFailure,
    this.message,
    this.isDeleted = false,
  });

  final String userId;
  final AdminUserDetail? detail;
  final bool isLoading;

  /// An action is in flight; buttons disable.
  final bool isBusy;
  final Failure? failure;
  final Failure? actionFailure;

  /// One-shot confirmation copy ("User suspended.").
  final String? message;
  final bool isDeleted;

  AdminUserDetailState copyWith({
    AdminUserDetail? detail,
    bool? isLoading,
    bool? isBusy,
    Failure? failure,
    Failure? actionFailure,
    String? message,
    bool? isDeleted,
    bool clearFeedback = false,
  }) {
    return AdminUserDetailState(
      userId: userId,
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      failure: failure ?? this.failure,
      actionFailure: clearFeedback ? null : actionFailure ?? this.actionFailure,
      message: clearFeedback ? null : message ?? this.message,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props =>
      [userId, detail, isLoading, isBusy, failure, actionFailure, message, isDeleted];
}

/// One user in the admin console: roles, OSINT, sanctions, deletion.
class AdminUserDetailCubit extends Cubit<AdminUserDetailState> {
  AdminUserDetailCubit({
    required String userId,
    required GetAdminUserDetail getDetail,
    required GrantRole grantRole,
    required RevokeRole revokeRole,
    required RevokeOsint revokeOsint,
    required BanUser banUser,
    required UnbanUser unbanUser,
    required LiftSanction liftSanction,
    required WarnUser warnUser,
    required AdminDeleteAccount deleteAccount,
  })  : _getDetail = getDetail,
        _grantRole = grantRole,
        _revokeRole = revokeRole,
        _revokeOsint = revokeOsint,
        _banUser = banUser,
        _unbanUser = unbanUser,
        _liftSanction = liftSanction,
        _warnUser = warnUser,
        _deleteAccount = deleteAccount,
        super(AdminUserDetailState(userId: userId));

  final GetAdminUserDetail _getDetail;
  final GrantRole _grantRole;
  final RevokeRole _revokeRole;
  final RevokeOsint _revokeOsint;
  final BanUser _banUser;
  final UnbanUser _unbanUser;
  final LiftSanction _liftSanction;
  final WarnUser _warnUser;
  final AdminDeleteAccount _deleteAccount;

  String get _userId => state.userId;

  Future<void> load() async {
    final result = await _getDetail(_userId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (detail) => emit(state.copyWith(isLoading: false, detail: detail)),
    );
  }

  Future<bool> grantRole(AppRole role) => _run(
        () => _grantRole(RoleParams(userId: _userId, role: role)),
        '${role.label} granted.',
      );

  Future<bool> revokeRole(AppRole role, {String? reason}) => _run(
        () => _revokeRole(RoleParams(userId: _userId, role: role, reason: reason)),
        '${role.label} removed.',
      );

  /// Downgrade from OSINT analyst (logged as a sanction).
  Future<bool> revokeOsint(String reason) => _run(
        () => _revokeOsint(UserReasonParams(userId: _userId, reason: reason)),
        'OSINT access revoked.',
      );

  Future<bool> ban({
    required String reason,
    Duration? duration,
    bool hideContent = false,
  }) =>
      _run(
        () => _banUser(BanUserParams(
          userId: _userId,
          reason: reason,
          duration: duration,
          hideContent: hideContent,
        )),
        duration == null ? 'User banned.' : 'User suspended.',
      );

  Future<bool> unban({String? reason}) => _run(
        () => _unbanUser(UserReasonParams(userId: _userId, reason: reason)),
        'Ban lifted.',
      );

  Future<bool> liftSanction(int sanctionId, {String? reason}) => _run(
        () => _liftSanction(
            LiftSanctionParams(sanctionId: sanctionId, reason: reason)),
        'Sanction lifted.',
      );

  Future<bool> warn(String reason) => _run(
        () => _warnUser(WarnUserParams(userId: _userId, reason: reason)),
        'Warning sent.',
      );

  Future<bool> deleteAccount(String reason) async {
    emit(state.copyWith(isBusy: true, clearFeedback: true));
    final result =
        await _deleteAccount(UserReasonParams(userId: _userId, reason: reason));
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(state.copyWith(isBusy: false, actionFailure: failure));
        return false;
      },
      (_) {
        emit(state.copyWith(
            isBusy: false, isDeleted: true, message: 'Account deleted.'));
        return true;
      },
    );
  }

  void clearFeedback() => emit(state.copyWith(clearFeedback: true));

  /// Runs a write, then reloads the user so roles / sanctions stay truthful.
  Future<bool> _run(
      Future<Result<dynamic>> Function() action, String successMessage) async {
    if (state.isBusy) return false;
    emit(state.copyWith(isBusy: true, clearFeedback: true));
    final result = await action();
    if (isClosed) return false;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(isBusy: false, actionFailure: failure));
      return false;
    }
    await load();
    if (isClosed) return true;
    emit(state.copyWith(isBusy: false, message: successMessage));
    return true;
  }
}
