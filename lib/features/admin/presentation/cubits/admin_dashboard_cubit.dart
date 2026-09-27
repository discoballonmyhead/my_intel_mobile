import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../moderation/domain/usecases/report_usecases.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/usecases/admin_usecases.dart';

class AdminDashboardState extends Equatable {
  const AdminDashboardState({
    this.stats,
    this.isLoading = true,
    this.failure,
  });

  final AdminStats? stats;
  final bool isLoading;
  final Failure? failure;

  @override
  List<Object?> get props => [stats, isLoading, failure];
}

/// Headline numbers for the console home. Refreshes live when reports land.
class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  AdminDashboardCubit({
    required GetAdminStats getStats,
    required WatchReports watchReports,
  })  : _getStats = getStats,
        _watchReports = watchReports,
        super(const AdminDashboardState());

  final GetAdminStats _getStats;
  final WatchReports _watchReports;
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  Future<void> load() async {
    final result = await _getStats(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(AdminDashboardState(
          stats: state.stats, isLoading: false, failure: failure)),
      (stats) => emit(AdminDashboardState(stats: stats, isLoading: false)),
    );
    _sub ??= _watchReports(const NoParams()).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 1), load);
    });
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
