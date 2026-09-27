import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/report_usecases.dart';

class MyReportsState extends Equatable {
  const MyReportsState({
    this.reports = const [],
    this.isLoading = true,
    this.failure,
  });

  final List<Report> reports;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => [reports, isLoading, failure];
}

/// Reports the signed-in user filed, with their outcome.
class MyReportsCubit extends Cubit<MyReportsState> {
  MyReportsCubit({required GetMyReports getMyReports})
      : _getMyReports = getMyReports,
        super(const MyReportsState());

  final GetMyReports _getMyReports;

  Future<void> load() async {
    final result = await _getMyReports(const PageParams(limit: 100));
    if (isClosed) return;
    result.fold(
      (failure) => emit(MyReportsState(
          reports: state.reports, isLoading: false, failure: failure)),
      (reports) => emit(MyReportsState(reports: reports, isLoading: false)),
    );
  }
}
