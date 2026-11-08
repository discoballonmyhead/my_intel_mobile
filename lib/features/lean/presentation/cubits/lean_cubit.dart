import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../data/lean_repository.dart';
import '../../domain/lean.dart';

class LeanState extends Equatable {
  const LeanState({
    this.status = LeanStatus.disabled,
    this.loaded = false,
    this.busy = false,
    this.failure,
  });

  final LeanStatus status;

  /// The first answer from the server arrived.
  final bool loaded;

  /// A change is being saved.
  final bool busy;
  final Failure? failure;

  LeanState copyWith(
          {LeanStatus? status,
          bool? loaded,
          bool? busy,
          Failure? failure,
          bool clearFailure = false}) =>
      LeanState(
        status: status ?? this.status,
        loaded: loaded ?? this.loaded,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : failure ?? this.failure,
      );

  @override
  List<Object?> get props => [status, loaded, busy, failure];
}

/// The user's compass. Recomputed by the server each time the app opens or
/// comes back to the foreground ([refresh]); private to the user.
class LeanCubit extends Cubit<LeanState> {
  LeanCubit(this._repository,
      {void Function()? onFilterChanged, String? Function()? currentUserId})
      : _onFilterChanged = onFilterChanged,
        _currentUserId = currentUserId,
        super(const LeanState());

  final LeanRepository _repository;

  /// Called after the feed filter changed, so the feed can reload.
  final void Function()? _onFilterChanged;

  /// Who is signed in right now, so the cubit works even when nothing calls
  /// [syncWithUser] (e.g. a main.dart without the compass lines).
  final String? Function()? _currentUserId;
  String? _userId;

  Future<void> syncWithUser(String? userId) async {
    if (userId == _userId && state.loaded) return;
    _userId = userId;
    emit(const LeanState());
    if (userId != null) await refresh();
  }

  Future<void> refresh() async {
    final now = _currentUserId?.call() ?? _userId;
    if (now != _userId) {
      // another account (or signed out): never show the previous one's compass
      _userId = now;
      emit(const LeanState());
    }
    if (_userId == null) return;
    final result = await _repository.me();
    if (isClosed) return;
    result.fold(
      // The compass is optional: if the server doesn't have it yet
      // (migration 28 not run), stay quietly "off".
      (f) => emit(state.copyWith(loaded: true, failure: f)),
      (s) => emit(state.copyWith(status: s, loaded: true, clearFailure: true)),
    );
  }

  Future<bool> enable() => _apply(
      () => _repository.setSettings(enabled: true, mode: state.status.mode));

  /// Turns it off and deletes the history on the server.
  Future<bool> disable() =>
      _apply(() => _repository.setSettings(enabled: false),
          filterChanged: true);

  Future<bool> setMode(LeanMode mode, {LeanPoint? spot}) {
    final where = mode == LeanMode.spot
        ? (spot ?? state.status.spot ?? LeanPoint.centre)
        : null;
    return _apply(
        () => _repository.setSettings(
            enabled: true, mode: mode, spot: where?.clamp()),
        filterChanged: true);
  }

  Future<bool> setSpot(LeanPoint spot) => setMode(LeanMode.spot, spot: spot);

  Future<bool> resetHistory() => _apply(_repository.reset);

  Future<bool> _apply(Future<Result<LeanStatus>> Function() action,
      {bool filterChanged = false}) async {
    if (state.busy) return false;
    final before = state.status.mode;
    emit(state.copyWith(busy: true, clearFailure: true));
    final result = await action();
    if (isClosed) return false;
    return result.fold(
      (f) {
        emit(state.copyWith(busy: false, failure: f));
        return false;
      },
      (s) {
        emit(state.copyWith(status: s, busy: false, loaded: true));
        if (filterChanged || s.mode != before) _onFilterChanged?.call();
        return true;
      },
    );
  }
}
