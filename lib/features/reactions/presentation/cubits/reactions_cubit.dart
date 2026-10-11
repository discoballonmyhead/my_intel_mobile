import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/reaction.dart';
import '../../domain/usecases/reaction_usecases.dart';

class ReactionsState extends Equatable {
  const ReactionsState({
    this.userId,
    this.byPost = const {},
    this.pending = const {},
    this.failure,
  });

  final String? userId;

  /// Loaded summaries, keyed by post id.
  final Map<int, ReactionSummary> byPost;

  /// Posts with a toggle in flight (their bar ignores taps meanwhile).
  final Set<int> pending;
  final Failure? failure;

  ReactionsState copyWith({
    Map<int, ReactionSummary>? byPost,
    Set<int>? pending,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ReactionsState(
      userId: userId,
      byPost: byPost ?? this.byPost,
      pending: pending ?? this.pending,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [userId, byPost, pending, failure];
}

/// App-wide reaction state. Every [ReactionBar] on screen calls [request];
/// requests made within a frame or two are sent as one batched RPC, so a feed
/// page costs a single round trip. Reset on account change because
/// `user_reaction` is per viewer.
class ReactionsCubit extends Cubit<ReactionsState> {
  ReactionsCubit({
    required GetReactionsForPosts getReactionsForPosts,
    required ToggleReaction toggleReaction,
  })  : _getForPosts = getReactionsForPosts,
        _toggle = toggleReaction,
        super(const ReactionsState());

  final GetReactionsForPosts _getForPosts;
  final ToggleReaction _toggle;

  static const Duration _batchWindow = Duration(milliseconds: 60);

  final Set<int> _queued = {};
  final Set<int> _inFlight = {};
  Timer? _flush;

  /// Bumped on every account change so late responses for the previous user
  /// are dropped.
  int _session = 0;

  void syncWithUser(String? userId) {
    if (userId == state.userId) return;
    _session++;
    _flush?.cancel();
    _flush = null;
    _queued.clear();
    _inFlight.clear();
    emit(ReactionsState(userId: userId));
  }

  /// Loads summaries for [postIds] that aren't loaded or loading yet.
  void request(Iterable<int> postIds) {
    if (state.userId == null) return;
    final missing = postIds.where((id) =>
        !state.byPost.containsKey(id) && !_inFlight.contains(id));
    if (missing.isEmpty) return;
    _queued.addAll(missing);
    _flush ??= Timer(_batchWindow, _drain);
  }

  /// Re-fetches [postIds] even if cached (pull-to-refresh).
  Future<void> refresh(Iterable<int> postIds) async {
    final ids = postIds.toList();
    if (ids.isEmpty || state.userId == null) return;
    await _load(ids);
  }

  Future<void> _drain() async {
    _flush = null;
    final ids = _queued.toList();
    _queued.clear();
    if (ids.isEmpty) return;
    await _load(ids);
  }

  Future<void> _load(List<int> ids) async {
    final session = _session;
    _inFlight.addAll(ids);
    final result = await _getForPosts(ids);
    _inFlight.removeAll(ids);
    if (isClosed || session != _session) return;

    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (loaded) {
        // Don't overwrite a post whose toggle is still in flight.
        final fresh = Map.of(loaded)
          ..removeWhere((id, _) => state.pending.contains(id));
        emit(state.copyWith(byPost: {...state.byPost, ...fresh}));
      },
    );
  }

  Future<void> toggle(int postId, ReactionType type) async {
    if (state.userId == null || state.pending.contains(postId)) return;
    final session = _session;
    final before = state.byPost[postId] ?? ReactionSummary(postId: postId);

    emit(state.copyWith(
      byPost: {...state.byPost, postId: before.toggled(type)},
      pending: {...state.pending, postId},
      clearFailure: true,
    ));

    final result =
        await _toggle(ToggleReactionParams(postId: postId, type: type));
    if (isClosed || session != _session) return;

    final pending = {...state.pending}..remove(postId);
    result.fold(
      (failure) => emit(state.copyWith(
        byPost: {...state.byPost, postId: before},
        pending: pending,
        failure: failure,
      )),
      (summary) => emit(state.copyWith(
        byPost: {...state.byPost, postId: summary},
        pending: pending,
      )),
    );
  }

  void clearFailure() => emit(state.copyWith(clearFailure: true));

  @override
  Future<void> close() {
    _flush?.cancel();
    return super.close();
  }
}
