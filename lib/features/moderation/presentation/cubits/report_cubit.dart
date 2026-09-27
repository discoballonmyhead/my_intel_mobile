import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/report_usecases.dart';

class ReportFormState extends Equatable {
  const ReportFormState({
    this.reason,
    this.details = '',
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.failure,
  });

  final ReportReason? reason;
  final String details;
  final bool isSubmitting;
  final bool isSubmitted;
  final Failure? failure;

  bool get canSubmit => reason != null && !isSubmitting && !isSubmitted;

  ReportFormState copyWith({
    ReportReason? reason,
    String? details,
    bool? isSubmitting,
    bool? isSubmitted,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ReportFormState(
      reason: reason ?? this.reason,
      details: details ?? this.details,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [reason, details, isSubmitting, isSubmitted, failure];
}

/// The "Report" sheet on posts, messages and profiles.
class ReportCubit extends Cubit<ReportFormState> {
  ReportCubit({required SubmitReport submitReport})
      : _submitReport = submitReport,
        super(const ReportFormState());

  final SubmitReport _submitReport;

  void selectReason(ReportReason reason) =>
      emit(state.copyWith(reason: reason, clearFailure: true));

  void setDetails(String details) =>
      emit(state.copyWith(details: details, clearFailure: true));

  Future<void> submit(ReportTarget target) async {
    final reason = state.reason;
    if (reason == null || !state.canSubmit) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _submitReport(SubmitReportParams(
      targetType: target.type,
      targetId: target.id,
      reason: reason,
      details: state.details,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
      (_) => emit(state.copyWith(isSubmitting: false, isSubmitted: true)),
    );
  }
}
