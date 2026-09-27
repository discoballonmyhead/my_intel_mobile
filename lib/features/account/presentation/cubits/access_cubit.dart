import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/usecases/account_usecases.dart';

enum AccessStatus { signedOut, loading, ready, error }

class AccessState extends Equatable {
  const AccessState({
    this.status = AccessStatus.signedOut,
    this.access = UserAccess.none,
    this.userId,
    this.failure,
  });

  final AccessStatus status;
  final UserAccess access;
  final String? userId;
  final Failure? failure;

  /// Router guards wait for this before redirecting away from staff routes,
  /// so a deep link to /admin isn't bounced while access is still loading.
  bool get isResolved =>
      status == AccessStatus.ready || status == AccessStatus.error;

  bool get isStaff => access.isStaff;
  bool get isAdmin => access.isAdmin;
  bool get isBanned => access.isBanned;

  AccessState copyWith({
    AccessStatus? status,
    UserAccess? access,
    String? userId,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AccessState(
      status: status ?? this.status,
      access: access ?? this.access,
      userId: userId ?? this.userId,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, access, userId, failure];
}

/// App-wide source of truth for roles and bans. Synced with the auth session
/// in `main.dart`, refreshed live when an admin changes this user's roles or
/// sanctions, and read by the router to gate staff routes.
class AccessCubit extends Cubit<AccessState> {
  AccessCubit({
    required GetMyAccess getMyAccess,
    required WatchAccessChanges watchAccessChanges,
  })  : _getMyAccess = getMyAccess,
        _watchAccessChanges = watchAccessChanges,
        super(const AccessState());

  final GetMyAccess _getMyAccess;
  final WatchAccessChanges _watchAccessChanges;
  StreamSubscription<void>? _changes;

  Future<void> syncWithUser(String? userId) async {
    if (userId == state.userId && state.status != AccessStatus.signedOut) return;

    await _changes?.cancel();
    _changes = null;

    if (userId == null) {
      emit(const AccessState());
      return;
    }

    emit(AccessState(status: AccessStatus.loading, userId: userId));
    await refresh();
    if (isClosed || state.userId != userId) return;
    _changes = _watchAccessChanges(userId).listen((_) => refresh());
  }

  Future<void> refresh() async {
    final userId = state.userId;
    if (userId == null) return;
    final result = await _getMyAccess(const NoParams());
    if (isClosed || state.userId != userId) return;
    result.fold(
      (failure) => emit(state.copyWith(
        status: AccessStatus.error,
        failure: failure,
      )),
      (access) => emit(state.copyWith(
        status: AccessStatus.ready,
        access: access,
        clearFailure: true,
      )),
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
