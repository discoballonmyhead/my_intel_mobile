import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../admin/domain/usecases/admin_usecases.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/report_usecases.dart';

class ReportDetailState extends Equatable {
  const ReportDetailState({
    required this.target,
    this.reports = const [],
    this.isLoading = true,
    this.isBusy = false,
    this.failure,
    this.actionFailure,
    this.message,
    this.isResolved = false,
  });

  final ReportTarget target;
  final List<Report> reports;
  final bool isLoading;
  final bool isBusy;
  final Failure? failure;
  final Failure? actionFailure;
  final String? message;

  /// Every report on this target is closed → the page can pop.
  final bool isResolved;

  Report? get latest => reports.isEmpty ? null : reports.first;
  String? get ownerId => latest?.targetOwnerId;
  ReportSnapshot get snapshot => latest?.snapshot ?? const ReportSnapshot(null);
  bool get hasPending => reports.any((r) => r.status.isPending);

  ReportDetailState copyWith({
    List<Report>? reports,
    bool? isLoading,
    bool? isBusy,
    Failure? failure,
    Failure? actionFailure,
    String? message,
    bool? isResolved,
    bool clearFeedback = false,
  }) {
    return ReportDetailState(
      target: target,
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      failure: failure ?? this.failure,
      actionFailure: clearFeedback ? null : actionFailure ?? this.actionFailure,
      message: clearFeedback ? null : message ?? this.message,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  @override
  List<Object?> get props => [
        target,
        reports,
        isLoading,
        isBusy,
        failure,
        actionFailure,
        message,
        isResolved,
      ];
}

/// Everything a moderator does with one reported item: claim it, dismiss,
/// remove the content, warn or suspend/ban the owner.
class ReportDetailCubit extends Cubit<ReportDetailState> {
  ReportDetailCubit({
    required ReportTarget target,
    required GetReportsForTarget getReports,
    required ClaimReportTarget claim,
    required ResolveReportTarget resolve,
    required ModRemovePost removePost,
    required ModRestorePost restorePost,
    required ModRemoveMessage removeMessage,
    required ModRemoveComment removeComment,
    required WarnUser warnUser,
    required BanUser banUser,
  })  : _getReports = getReports,
        _claim = claim,
        _resolve = resolve,
        _removePost = removePost,
        _restorePost = restorePost,
        _removeMessage = removeMessage,
        _removeComment = removeComment,
        _warnUser = warnUser,
        _banUser = banUser,
        super(ReportDetailState(target: target));

  final GetReportsForTarget _getReports;
  final ClaimReportTarget _claim;
  final ResolveReportTarget _resolve;
  final ModRemovePost _removePost;
  final ModRestorePost _restorePost;
  final ModRemoveMessage _removeMessage;
  final ModRemoveComment _removeComment;
  final WarnUser _warnUser;
  final BanUser _banUser;

  ReportTarget get _target => state.target;
  int? get _numericId => int.tryParse(_target.id);

  Future<void> load() async {
    final result = await _getReports(_target);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (reports) => emit(state.copyWith(isLoading: false, reports: reports)),
    );
  }

  Future<bool> claim() => _run(() => _claim(_target), 'Assigned to you.');

  Future<bool> dismiss(String? note) => _run(
        () => _resolve(ResolveReportsParams(
          target: _target,
          outcome: ReportStatus.dismissed,
          action: 'no_violation',
          note: note,
        )),
        'Reports dismissed.',
        resolves: true,
      );

  /// Removes the content itself. Posts and messages have dedicated RPCs that
  /// also close their reports; other types are closed as actioned so the
  /// team can take it down wherever it lives.
  Future<bool> removeContent(String reason) {
    final id = _numericId;
    return switch (_target.type) {
      ReportTargetType.post when id != null => _run(
          () => _removePost(ModContentParams(id: id, reason: reason)),
          'Post removed.',
          resolves: true,
        ),
      ReportTargetType.comment when id != null => _run(
          () => _removeComment(ModContentParams(id: id, reason: reason)),
          'Comment removed.',
          resolves: true,
        ),
      ReportTargetType.message when id != null => _run(
          () => _removeMessage(ModContentParams(id: id, reason: reason)),
          'Message removed.',
          resolves: true,
        ),
      _ => _run(
          () => _resolve(ResolveReportsParams(
            target: _target,
            outcome: ReportStatus.actioned,
            action: 'content_removed',
            note: reason,
          )),
          'Marked as actioned.',
          resolves: true,
        ),
    };
  }

  Future<bool> restorePost(String? reason) {
    final id = _numericId;
    if (_target.type != ReportTargetType.post || id == null) {
      return Future.value(false);
    }
    return _run(
      () => _restorePost(ModContentParams(id: id, reason: reason)),
      'Post restored.',
    );
  }

  Future<bool> warnOwner(String reason) async {
    final owner = state.ownerId;
    if (owner == null) return false;
    final ok = await _run(
      () => _warnUser(WarnUserParams(
        userId: owner,
        reason: reason,
        reportId: state.latest?.id,
      )),
      'Warning sent.',
    );
    if (!ok) return false;
    return _run(
      () => _resolve(ResolveReportsParams(
        target: _target,
        outcome: ReportStatus.actioned,
        action: 'user_warned',
        note: reason,
      )),
      'Warning sent.',
      resolves: true,
    );
  }

  /// [duration] null = permanent ban (admins only; the RPC enforces it).
  Future<bool> sanctionOwner({
    required String reason,
    Duration? duration,
    bool hideContent = false,
  }) async {
    final owner = state.ownerId;
    if (owner == null) return false;
    return _run(
      () => _banUser(BanUserParams(
        userId: owner,
        reason: reason,
        duration: duration,
        hideContent: hideContent,
        reportId: state.latest?.id,
      )),
      duration == null ? 'User banned.' : 'User suspended.',
      resolves: true,
    );
  }

  void clearFeedback() => emit(state.copyWith(clearFeedback: true));

  Future<bool> _run(
    Future<Result<dynamic>> Function() action,
    String successMessage, {
    bool resolves = false,
  }) async {
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
    emit(state.copyWith(
      isBusy: false,
      message: successMessage,
      isResolved: resolves && !state.hasPending,
    ));
    return true;
  }
}
