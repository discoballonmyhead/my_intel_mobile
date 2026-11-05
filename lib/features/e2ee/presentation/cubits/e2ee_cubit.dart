import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/e2ee_api.dart';
import '../../data/e2ee_service.dart';

class E2eeState extends Equatable {
  const E2eeState({
    this.setup = E2eeSetup.idle,
    this.hasBackup,
    this.busy = false,
    this.error,
  });

  final E2eeSetup setup;

  /// Null until known.
  final bool? hasBackup;
  final bool busy;
  final String? error;

  bool get isReady => setup == E2eeSetup.ready;
  bool get needsRestore => setup == E2eeSetup.needsRestore;

  /// Ready, but nothing protects the keys if this phone is lost.
  bool get shouldOfferBackup => isReady && hasBackup == false;

  E2eeState copyWith({E2eeSetup? setup, bool? hasBackup, bool? busy, String? error, bool clearError = false}) =>
      E2eeState(
        setup: setup ?? this.setup,
        hasBackup: hasBackup ?? this.hasBackup,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [setup, hasBackup, busy, error];
}

/// Session-wide: sets up encryption keys at sign-in, keeps prekeys topped up,
/// picks up group keys as they arrive, and runs the PIN backup screens.
class E2eeCubit extends Cubit<E2eeState> {
  E2eeCubit({required E2eeService service, required E2eeRemoteDataSource api})
      : _service = service,
        _api = api,
        super(const E2eeState());

  final E2eeService _service;
  final E2eeRemoteDataSource _api;
  StreamSubscription<void>? _senderKeys;
  String? _userId;

  E2eeService get service => _service;

  Future<void> syncWithUser(String? userId) async {
    if (userId == _userId && state.setup != E2eeSetup.idle) return;
    _userId = userId;
    await _senderKeys?.cancel();
    _senderKeys = null;
    if (userId == null) {
      await _service.signOut();
      emit(const E2eeState());
      return;
    }
    await retry();
  }

  Future<void> retry() async {
    final userId = _userId;
    if (userId == null) return;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final setup = await _service.prepare(userId);
      final hasBackup = await _service.hasBackup();
      if (isClosed || userId != _userId) return;
      emit(E2eeState(setup: setup, hasBackup: hasBackup));
      if (setup == E2eeSetup.ready) _listen(userId);
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: 'Secure messaging couldn’t start. Check your connection.'));
    }
  }

  void _listen(String userId) {
    _senderKeys ??= _api.watchSenderKeys(userId).listen((_) {
      unawaited(_service.processSenderKeys().catchError((Object _) {}));
    });
    unawaited(_service.processSenderKeys().catchError((Object _) {}));
  }

  /// Returns null on success, otherwise a message to show.
  Future<String?> createBackup(String pin) async {
    final problem = pinProblem(pin);
    if (problem != null) return problem;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _service.createBackup(pin);
      emit(state.copyWith(busy: false, hasBackup: true));
      return null;
    } catch (_) {
      emit(state.copyWith(busy: false));
      return 'Couldn’t save the backup. Check your connection and try again.';
    }
  }

  Future<RestoreResult> restore(String pin) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final result = await _service.restore(pin);
      if (result.ok) {
        emit(const E2eeState(setup: E2eeSetup.ready, hasBackup: true));
        if (_userId != null) _listen(_userId!);
      } else {
        emit(state.copyWith(busy: false, hasBackup: !(result.wiped || result.noBackup)));
        if (result.wiped || result.noBackup) await startFresh();
      }
      return result;
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Couldn’t restore. Check your connection and try again.'));
      return const RestoreResult.wrongPin(null);
    }
  }

  /// New keys without the backup (old messages stay unreadable here).
  Future<void> startFresh() async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _service.startFresh();
      emit(E2eeState(setup: E2eeSetup.ready, hasBackup: await _service.hasBackup()));
      if (_userId != null) _listen(_userId!);
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Couldn’t set up secure messaging. Try again.'));
    }
  }

  Future<void> deleteBackup() async {
    emit(state.copyWith(busy: true));
    try {
      await _service.deleteBackup();
      emit(state.copyWith(busy: false, hasBackup: false));
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Couldn’t turn off the backup.'));
    }
  }

  Future<String?> safetyNumber(String userId) => _service.safetyNumber(userId);

  Future<void> markVerified(String userId) => _service.markVerified(userId);

  Future<({bool verified, bool changed})> trustOf(String userId) => _service.trustOf(userId);

  /// At least 6 digits (or a longer passphrase).
  static String? pinProblem(String pin) {
    final p = pin.trim();
    if (p.length < 6) return 'Use at least 6 digits.';
    if (RegExp(r'^(\d)\1+$').hasMatch(p) || '01234567890'.contains(p) || '9876543210'.contains(p)) {
      return 'That PIN is too easy to guess.';
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _senderKeys?.cancel();
    return super.close();
  }
}
