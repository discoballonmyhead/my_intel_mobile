import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/usecases/admin_usecases.dart';

class AuditLogState extends Equatable {
  const AuditLogState({
    this.entries = const [],
    this.action,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.failure,
  });

  final List<AuditEntry> entries;

  /// Filter by action key, e.g. `user_ban`.
  final String? action;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? failure;

  @override
  List<Object?> get props =>
      [entries, action, isLoading, isLoadingMore, hasMore, failure];
}

class AuditLogCubit extends Cubit<AuditLogState> {
  AuditLogCubit({required GetAuditLog getAuditLog})
      : _getAuditLog = getAuditLog,
        super(const AuditLogState());

  final GetAuditLog _getAuditLog;
  static const _pageSize = 100;

  /// Actions the filter menu offers (see the SQL `admin.write_audit` calls).
  static const List<String> knownActions = [
    'osint_approve',
    'osint_decline',
    'osint_revoke',
    'role_grant',
    'role_revoke',
    'user_warn',
    'user_suspend',
    'user_ban',
    'user_unban',
    'sanction_lift',
    'post_remove',
    'post_restore',
    'post_visibility_limited',
    'post_visibility_under_review',
    'post_visibility_visible',
    'message_remove',
    'reports_actioned',
    'reports_dismissed',
    'account_delete',
    'account_delete_self',
  ];

  Future<void> load({String? action}) async {
    emit(AuditLogState(action: action));
    final result =
        await _getAuditLog(AuditLogQuery(limit: _pageSize, action: action));
    if (isClosed) return;
    result.fold(
      (failure) => emit(AuditLogState(
          action: action, isLoading: false, failure: failure)),
      (entries) => emit(AuditLogState(
        action: action,
        entries: entries,
        isLoading: false,
        hasMore: entries.length >= _pageSize,
      )),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final s = state;
    emit(AuditLogState(
      action: s.action,
      entries: s.entries,
      isLoading: false,
      isLoadingMore: true,
    ));
    final result = await _getAuditLog(AuditLogQuery(
      limit: _pageSize,
      offset: s.entries.length,
      action: s.action,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(AuditLogState(
        action: s.action,
        entries: s.entries,
        isLoading: false,
        failure: failure,
      )),
      (more) => emit(AuditLogState(
        action: s.action,
        entries: [...s.entries, ...more],
        isLoading: false,
        hasMore: more.length >= _pageSize,
      )),
    );
  }
}
