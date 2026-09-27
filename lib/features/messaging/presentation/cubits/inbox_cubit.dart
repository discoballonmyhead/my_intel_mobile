import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/messaging_usecases.dart';

enum InboxStatus { idle, loading, ready, error }

class InboxState extends Equatable {
  const InboxState({
    this.status = InboxStatus.idle,
    this.entries = const [],
    this.unreadTotal = 0,
    this.userId,
    this.failure,
  });

  final InboxStatus status;
  final List<InboxEntry> entries;

  /// Badge count on the Messages tab (muted conversations excluded).
  final int unreadTotal;
  final String? userId;
  final Failure? failure;

  bool get isEmpty => status == InboxStatus.ready && entries.isEmpty;

  InboxState copyWith({
    InboxStatus? status,
    List<InboxEntry>? entries,
    int? unreadTotal,
    String? userId,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return InboxState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      unreadTotal: unreadTotal ?? this.unreadTotal,
      userId: userId ?? this.userId,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [status, entries, unreadTotal, userId, failure];
}

/// App-wide inbox. Lives for the whole session so the tab badge stays live;
/// realtime ticks are debounced into one reload.
class InboxCubit extends Cubit<InboxState> {
  InboxCubit({
    required GetInbox getInbox,
    required GetUnreadTotal getUnreadTotal,
    required WatchInbox watchInbox,
    required DeleteConversation deleteConversation,
    required SetConversationMuted setConversationMuted,
    required OpenDirectConversation openDirectConversation,
  })  : _getInbox = getInbox,
        _getUnreadTotal = getUnreadTotal,
        _watchInbox = watchInbox,
        _deleteConversation = deleteConversation,
        _setMuted = setConversationMuted,
        _openDirect = openDirectConversation,
        super(const InboxState());

  final GetInbox _getInbox;
  final GetUnreadTotal _getUnreadTotal;
  final WatchInbox _watchInbox;
  final DeleteConversation _deleteConversation;
  final SetConversationMuted _setMuted;
  final OpenDirectConversation _openDirect;

  StreamSubscription<void>? _realtime;
  Timer? _debounce;

  static const _mutedForever = Duration(days: 365 * 100);

  Future<void> syncWithUser(String? userId) async {
    if (userId == state.userId && state.status != InboxStatus.idle) return;

    _debounce?.cancel();
    await _realtime?.cancel();
    _realtime = null;

    if (userId == null) {
      emit(const InboxState());
      return;
    }

    emit(InboxState(status: InboxStatus.loading, userId: userId));
    await load(silent: true);
    if (isClosed || state.userId != userId) return;
    _realtime = _watchInbox(userId).listen((_) => _scheduleReload());
  }

  Future<void> load({bool silent = false}) async {
    final userId = state.userId;
    if (userId == null) return;
    if (!silent) emit(state.copyWith(status: InboxStatus.loading));

    final results = await Future.wait([
      _getInbox(const GetInboxParams(limit: 50)),
      _getUnreadTotal(const NoParams()),
    ]);
    if (isClosed || state.userId != userId) return;

    final inbox = results[0].valueOrNull as List<InboxEntry>?;
    final unread = results[1].valueOrNull as int?;

    if (inbox == null) {
      emit(state.copyWith(
        status: state.entries.isEmpty ? InboxStatus.error : InboxStatus.ready,
        failure: results[0].failureOrNull,
      ));
      return;
    }
    emit(state.copyWith(
      status: InboxStatus.ready,
      entries: inbox,
      unreadTotal: unread ?? _sumUnread(inbox),
      clearFailure: true,
    ));
  }

  Future<void> refresh() => load(silent: true);

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  int _sumUnread(List<InboxEntry> entries) => entries
      .where((e) => !e.isMuted)
      .fold(0, (sum, e) => sum + e.unreadCount);

  /// Clears the badge immediately when a chat is opened; the server catches up
  /// via `msg_mark_read` and the realtime tick that follows.
  void markLocallyRead(String conversationId) {
    final entries = state.entries
        .map((e) => e.conversationId == conversationId && e.hasUnread
            ? e.copyWith(unreadCount: 0)
            : e)
        .toList();
    emit(state.copyWith(entries: entries, unreadTotal: _sumUnread(entries)));
  }

  /// Returns the conversation id, or null (with [InboxState.failure] set).
  Future<String?> openDirect(String otherUserId) async {
    final result = await _openDirect(otherUserId);
    return result.fold(
      (failure) {
        emit(state.copyWith(failure: failure));
        return null;
      },
      (id) => id,
    );
  }

  Future<bool> deleteConversation(String conversationId) async {
    final previous = state.entries;
    final next =
        previous.where((e) => e.conversationId != conversationId).toList();
    emit(state.copyWith(entries: next, unreadTotal: _sumUnread(next)));

    final result = await _deleteConversation(conversationId);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(
        entries: previous,
        unreadTotal: _sumUnread(previous),
        failure: failure,
      ));
      return false;
    }
    return true;
  }

  Future<bool> toggleMute(InboxEntry entry) async {
    final muting = !entry.isMuted;
    _replace(entry.copyWith(isMuted: muting));

    final result = await _setMuted(SetMutedParams(
      conversationId: entry.conversationId,
      until: muting ? DateTime.now().toUtc().add(_mutedForever) : null,
    ));
    final failure = result.failureOrNull;
    if (failure != null) {
      _replace(entry);
      emit(state.copyWith(failure: failure));
      return false;
    }
    return true;
  }

  void _replace(InboxEntry entry) {
    final entries = state.entries
        .map((e) => e.conversationId == entry.conversationId ? entry : e)
        .toList();
    emit(state.copyWith(entries: entries, unreadTotal: _sumUnread(entries)));
  }

  void clearFailure() => emit(state.copyWith(clearFailure: true));

  @override
  Future<void> close() async {
    _debounce?.cancel();
    await _realtime?.cancel();
    return super.close();
  }
}
