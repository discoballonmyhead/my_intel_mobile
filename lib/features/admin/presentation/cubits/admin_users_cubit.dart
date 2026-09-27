import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/usecases/admin_usecases.dart';

class AdminUsersState extends Equatable {
  const AdminUsersState({
    this.users = const [],
    this.search = '',
    this.role,
    this.bannedOnly = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.failure,
  });

  final List<AdminUser> users;
  final String search;
  final AppRole? role;
  final bool bannedOnly;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? failure;

  AdminUsersState copyWith({
    List<AdminUser>? users,
    String? search,
    AppRole? role,
    bool clearRole = false,
    bool? bannedOnly,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AdminUsersState(
      users: users ?? this.users,
      search: search ?? this.search,
      role: clearRole ? null : role ?? this.role,
      bannedOnly: bannedOnly ?? this.bannedOnly,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props =>
      [users, search, role, bannedOnly, isLoading, isLoadingMore, hasMore, failure];
}

class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit({required GetAdminUsers getUsers})
      : _getUsers = getUsers,
        super(const AdminUsersState());

  final GetAdminUsers _getUsers;
  Timer? _debounce;
  int _token = 0;
  static const _pageSize = 50;

  AdminUsersQuery _query({int offset = 0}) => AdminUsersQuery(
        search: state.search,
        role: state.role,
        banned: state.bannedOnly ? true : null,
        limit: _pageSize,
        offset: offset,
      );

  Future<void> load() async {
    final token = ++_token;
    emit(state.copyWith(isLoading: true, clearFailure: true));
    final result = await _getUsers(_query());
    if (isClosed || token != _token) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (users) => emit(state.copyWith(
        isLoading: false,
        users: users,
        hasMore: users.length >= _pageSize,
      )),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final token = _token;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getUsers(_query(offset: state.users.length));
    if (isClosed || token != _token) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, failure: failure)),
      (more) => emit(state.copyWith(
        isLoadingMore: false,
        users: [...state.users, ...more],
        hasMore: more.length >= _pageSize,
      )),
    );
  }

  void setSearch(String search) {
    emit(state.copyWith(search: search));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), load);
  }

  void setRole(AppRole? role) {
    emit(state.copyWith(role: role, clearRole: role == null));
    load();
  }

  void setBannedOnly(bool value) {
    emit(state.copyWith(bannedOnly: value));
    load();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
