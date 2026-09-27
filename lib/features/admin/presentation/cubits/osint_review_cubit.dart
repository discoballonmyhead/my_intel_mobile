import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/usecases/admin_usecases.dart';

class OsintReviewState extends Equatable {
  const OsintReviewState({
    this.filter = OsintStatusFilter.pending,
    this.items = const [],
    this.isLoading = true,
    this.busyIds = const {},
    this.failure,
    this.actionFailure,
    this.message,
  });

  final OsintStatusFilter filter;
  final List<OsintApplicationReview> items;
  final bool isLoading;

  /// Applications with a write in flight.
  final Set<int> busyIds;
  final Failure? failure;
  final Failure? actionFailure;
  final String? message;

  OsintReviewState copyWith({
    OsintStatusFilter? filter,
    List<OsintApplicationReview>? items,
    bool? isLoading,
    Set<int>? busyIds,
    Failure? failure,
    Failure? actionFailure,
    String? message,
    bool clearFeedback = false,
    bool clearFailure = false,
  }) {
    return OsintReviewState(
      filter: filter ?? this.filter,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      busyIds: busyIds ?? this.busyIds,
      failure: clearFailure ? null : failure ?? this.failure,
      actionFailure: clearFeedback ? null : actionFailure ?? this.actionFailure,
      message: clearFeedback ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props =>
      [filter, items, isLoading, busyIds, failure, actionFailure, message];
}

/// Approve / decline OSINT analyst applications.
class OsintReviewCubit extends Cubit<OsintReviewState> {
  OsintReviewCubit({
    required GetOsintApplications getApplications,
    required ApproveOsint approveOsint,
    required DeclineOsint declineOsint,
    required RevokeOsint revokeOsint,
  })  : _getApplications = getApplications,
        _approve = approveOsint,
        _decline = declineOsint,
        _revoke = revokeOsint,
        super(const OsintReviewState());

  final GetOsintApplications _getApplications;
  final ApproveOsint _approve;
  final DeclineOsint _decline;
  final RevokeOsint _revoke;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result =
        await _getApplications(OsintApplicationsQuery(filter: state.filter));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (items) => emit(state.copyWith(isLoading: false, items: items)),
    );
  }

  void setFilter(OsintStatusFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, items: const []));
    load();
  }

  Future<bool> approve(OsintApplicationReview item, {String? note}) =>
      _review(item, () => _approve(ReviewOsintParams(
            applicationId: item.application.id,
            note: note,
          )), 'Approved — ${item.profile?.username ?? 'user'} is now an analyst.');

  Future<bool> decline(OsintApplicationReview item, String reason) =>
      _review(item, () => _decline(ReviewOsintParams(
            applicationId: item.application.id,
            note: reason,
          )), 'Application declined.');

  Future<bool> revoke(OsintApplicationReview item, String reason) {
    final userId = item.application.userId;
    if (userId == null) return Future.value(false);
    return _review(
      item,
      () => _revoke(UserReasonParams(userId: userId, reason: reason)),
      'OSINT access revoked.',
    );
  }

  Future<bool> _review(
    OsintApplicationReview item,
    Future<Result<void>> Function() action,
    String successMessage,
  ) async {
    final id = item.application.id;
    emit(state.copyWith(busyIds: {...state.busyIds, id}, clearFeedback: true));
    final result = await action();
    if (isClosed) return false;
    final failure = result.failureOrNull;
    final busy = {...state.busyIds}..remove(id);
    if (failure != null) {
      emit(state.copyWith(busyIds: busy, actionFailure: failure));
      return false;
    }
    emit(state.copyWith(busyIds: busy, message: successMessage));
    await load();
    return true;
  }

  void clearFeedback() => emit(state.copyWith(clearFeedback: true));
}
