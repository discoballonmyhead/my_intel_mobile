import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/toggle_follow.dart';

class FollowListArgs {
  const FollowListArgs({required this.profileId, required this.kind});
  final String profileId;
  final FollowListKind kind;
}

class FollowListState extends Equatable {
  const FollowListState({
    required this.kind,
    this.entries = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.busyIds = const {},
    this.failure,
    this.actionFailure,
  });

  final FollowListKind kind;
  final List<FollowListEntry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Set<String> busyIds;
  final Failure? failure;
  final Failure? actionFailure;

  FollowListState copyWith({
    List<FollowListEntry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Set<String>? busyIds,
    Failure? failure,
    Failure? actionFailure,
    bool clearActionFailure = false,
  }) {
    return FollowListState(
      kind: kind,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      busyIds: busyIds ?? this.busyIds,
      failure: failure ?? this.failure,
      actionFailure:
          clearActionFailure ? null : actionFailure ?? this.actionFailure,
    );
  }

  @override
  List<Object?> get props =>
      [kind, entries, isLoading, isLoadingMore, hasMore, busyIds, failure, actionFailure];
}

class FollowListCubit extends Cubit<FollowListState> {
  FollowListCubit({
    required FollowListArgs args,
    required GetFollowList getFollowList,
    required SetFollowing setFollowing,
  })  : _profileId = args.profileId,
        _getFollowList = getFollowList,
        _setFollowing = setFollowing,
        super(FollowListState(kind: args.kind));

  final String _profileId;
  final GetFollowList _getFollowList;
  final SetFollowing _setFollowing;
  static const _pageSize = 50;

  Future<void> load() async {
    final result = await _getFollowList(
        FollowListParams(profileId: _profileId, kind: state.kind));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (entries) => emit(state.copyWith(
        isLoading: false,
        entries: entries,
        hasMore: entries.length >= _pageSize,
      )),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getFollowList(FollowListParams(
      profileId: _profileId,
      kind: state.kind,
      offset: state.entries.length,
    ));
    if (isClosed) return;
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoadingMore: false, actionFailure: failure)),
      (more) => emit(state.copyWith(
        isLoadingMore: false,
        entries: [...state.entries, ...more],
        hasMore: more.length >= _pageSize,
      )),
    );
  }

  Future<void> toggle(FollowListEntry entry) async {
    final id = entry.profile.id;
    if (state.busyIds.contains(id)) return;
    final follow = !entry.isFollowing;
    _replace(entry.copyWith(isFollowing: follow), busy: {...state.busyIds, id});

    final result = await _setFollowing(
        SetFollowingParams(targetUserId: id, follow: follow));
    if (isClosed) return;
    final busy = {...state.busyIds}..remove(id);
    result.fold(
      (failure) {
        _replace(entry, busy: busy);
        emit(state.copyWith(actionFailure: failure));
      },
      (stats) => _replace(entry.copyWith(isFollowing: stats.isFollowing),
          busy: busy),
    );
  }

  void _replace(FollowListEntry entry, {required Set<String> busy}) {
    emit(state.copyWith(
      busyIds: busy,
      entries: [
        for (final e in state.entries)
          e.profile.id == entry.profile.id ? entry : e,
      ],
    ));
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));
}
