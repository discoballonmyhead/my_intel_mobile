import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/report_usecases.dart';

class ModQueueState extends Equatable {
  const ModQueueState({
    this.status = ReportStatus.open,
    this.targetType,
    this.items = const [],
    this.isLoading = true,
    this.failure,
    this.hasNewActivity = false,
  });

  final ReportStatus status;
  final ReportTargetType? targetType;
  final List<ReportQueueItem> items;
  final bool isLoading;
  final Failure? failure;

  /// A report landed while the list was on screen.
  final bool hasNewActivity;

  ModQueueState copyWith({
    ReportStatus? status,
    ReportTargetType? targetType,
    bool clearTargetType = false,
    List<ReportQueueItem>? items,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    bool? hasNewActivity,
  }) {
    return ModQueueState(
      status: status ?? this.status,
      targetType: clearTargetType ? null : targetType ?? this.targetType,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      hasNewActivity: hasNewActivity ?? this.hasNewActivity,
    );
  }

  @override
  List<Object?> get props =>
      [status, targetType, items, isLoading, failure, hasNewActivity];
}

/// The moderator queue: one row per reported item, live-updating.
class ModQueueCubit extends Cubit<ModQueueState> {
  ModQueueCubit({
    required GetReportQueue getQueue,
    required WatchReports watchReports,
  })  : _getQueue = getQueue,
        _watchReports = watchReports,
        super(const ModQueueState());

  final GetReportQueue _getQueue;
  final WatchReports _watchReports;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _getQueue(ReportQueueParams(
      status: state.status,
      targetType: state.targetType,
      limit: 100,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (items) => emit(state.copyWith(
        isLoading: false,
        items: items,
        hasNewActivity: false,
        clearFailure: true,
      )),
    );
    _sub ??= _watchReports(const NoParams()).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        load(silent: true);
      });
    });
  }

  void setStatus(ReportStatus status) {
    if (status == state.status) return;
    emit(state.copyWith(status: status, items: const []));
    load();
  }

  void setTargetType(ReportTargetType? type) {
    emit(state.copyWith(targetType: type, clearTargetType: type == null));
    load();
  }

  /// Called after a detail page resolves something, so the row disappears.
  void removeLocally(ReportTarget target) => emit(state.copyWith(
        items: state.items.where((i) => i.target != target).toList(),
      ));

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
