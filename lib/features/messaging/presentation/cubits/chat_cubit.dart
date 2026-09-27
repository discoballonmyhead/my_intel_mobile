import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/messaging_usecases.dart';

enum ChatStatus { loading, ready, error }

class ChatState extends Equatable {
  const ChatState({
    required this.conversationId,
    this.myUserId,
    this.status = ChatStatus.loading,
    this.conversation,
    this.messages = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.replyTo,
    this.editing,
    this.failure,
    this.actionFailure,
    this.isClosedForMe = false,
  });

  final String conversationId;
  final String? myUserId;
  final ChatStatus status;
  final Conversation? conversation;

  /// Newest first — rendered by a `reverse: true` list.
  final List<Message> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final Message? replyTo;
  final Message? editing;

  /// Failure loading the conversation (shown full screen).
  final Failure? failure;

  /// Failure of a single action (shown as a snackbar, then cleared).
  final Failure? actionFailure;

  /// True after the user left / deleted the conversation → page pops.
  final bool isClosedForMe;

  String get title => conversation?.displayName(myUserId) ?? '';

  Message? messageById(int? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Highest message id every other member has read (DM read receipts).
  int? get seenByOthersUpTo {
    final others = conversation?.participants
            .where((p) => p.userId != myUserId)
            .toList() ??
        const <Participant>[];
    if (others.isEmpty) return null;
    return others
        .map((p) => p.lastReadMessageId ?? 0)
        .reduce((a, b) => a < b ? a : b);
  }

  /// The DM counterpart left the platform → composer is disabled.
  bool get recipientGone =>
      conversation != null &&
      !conversation!.isGroup &&
      conversation!.participants.length < 2;

  String senderName(String? senderId) {
    if (senderId == null) return 'Deleted user';
    if (senderId == myUserId) return 'You';
    return conversation?.participant(senderId)?.displayName ?? 'Former member';
  }

  ChatState copyWith({
    ChatStatus? status,
    Conversation? conversation,
    List<Message>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    Message? replyTo,
    Message? editing,
    Failure? failure,
    Failure? actionFailure,
    bool? isClosedForMe,
    bool clearReply = false,
    bool clearEditing = false,
    bool clearFailure = false,
    bool clearActionFailure = false,
  }) {
    return ChatState(
      conversationId: conversationId,
      myUserId: myUserId,
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      replyTo: clearReply ? null : replyTo ?? this.replyTo,
      editing: clearEditing ? null : editing ?? this.editing,
      failure: clearFailure ? null : failure ?? this.failure,
      actionFailure:
          clearActionFailure ? null : actionFailure ?? this.actionFailure,
      isClosedForMe: isClosedForMe ?? this.isClosedForMe,
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        status,
        conversation,
        messages,
        hasMore,
        isLoadingMore,
        isSending,
        replyTo,
        editing,
        failure,
        actionFailure,
        isClosedForMe,
      ];
}

/// One open conversation. Created per route (get_it factory) and closed with
/// the page, which also tears down its realtime channel.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required String conversationId,
    required String? myUserId,
    required GetConversation getConversation,
    required GetMessages getMessages,
    required SendMessage sendMessage,
    required EditMessage editMessage,
    required DeleteMessage deleteMessage,
    required MarkConversationRead markRead,
    required WatchConversation watchConversation,
    required LeaveConversation leaveConversation,
    required DeleteConversation deleteConversation,
    required SetConversationMuted setMuted,
    required UpdateGroup updateGroup,
    required RemoveGroupMember removeMember,
  })  : _getConversation = getConversation,
        _getMessages = getMessages,
        _sendMessage = sendMessage,
        _editMessage = editMessage,
        _deleteMessage = deleteMessage,
        _markRead = markRead,
        _watchConversation = watchConversation,
        _leave = leaveConversation,
        _deleteConversation = deleteConversation,
        _setMuted = setMuted,
        _updateGroup = updateGroup,
        _removeMember = removeMember,
        super(ChatState(conversationId: conversationId, myUserId: myUserId));

  final GetConversation _getConversation;
  final GetMessages _getMessages;
  final SendMessage _sendMessage;
  final EditMessage _editMessage;
  final DeleteMessage _deleteMessage;
  final MarkConversationRead _markRead;
  final WatchConversation _watchConversation;
  final LeaveConversation _leave;
  final DeleteConversation _deleteConversation;
  final SetConversationMuted _setMuted;
  final UpdateGroup _updateGroup;
  final RemoveGroupMember _removeMember;

  StreamSubscription<ConversationEvent>? _realtime;
  Timer? _markReadDebounce;
  Timer? _headerDebounce;

  String get _id => state.conversationId;

  // ── Loading ────────────────────────────────────────────────────────────

  Future<void> load() async {
    emit(state.copyWith(status: ChatStatus.loading, clearFailure: true));

    final conversation = await _getConversation(_id);
    if (isClosed) return;
    final header = conversation.valueOrNull;
    if (header == null) {
      emit(state.copyWith(
        status: ChatStatus.error,
        failure: conversation.failureOrNull,
      ));
      return;
    }

    final page = await _getMessages(GetMessagesParams(conversationId: _id));
    if (isClosed) return;
    final messages = page.valueOrNull;
    if (messages == null) {
      emit(state.copyWith(status: ChatStatus.error, failure: page.failureOrNull));
      return;
    }

    emit(state.copyWith(
      status: ChatStatus.ready,
      conversation: header,
      messages: messages,
      hasMore: messages.length >= MessagingPolicy.pageSize,
    ));

    _realtime ??= _watchConversation(_id).listen(_onEvent);
    _scheduleMarkRead();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.messages.isEmpty) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getMessages(GetMessagesParams(
      conversationId: _id,
      beforeId: state.messages.last.id,
    ));
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingMore: false,
        actionFailure: failure,
      )),
      (older) => emit(state.copyWith(
        isLoadingMore: false,
        messages: [...state.messages, ...older],
        hasMore: older.length >= MessagingPolicy.pageSize,
      )),
    );
  }

  Future<void> reloadHeader() async {
    final result = await _getConversation(_id);
    if (isClosed) return;
    final header = result.valueOrNull;
    if (header != null) {
      emit(state.copyWith(conversation: header));
    } else if (result.failureOrNull is PermissionFailure ||
        result.failureOrNull is NotFoundFailure) {
      // Removed from the group, or the conversation was purged.
      emit(state.copyWith(isClosedForMe: true));
    }
  }

  // ── Realtime ───────────────────────────────────────────────────────────

  void _onEvent(ConversationEvent event) {
    switch (event) {
      case MessageUpserted(:final message):
        _upsert(message);
        if (!message.isMine(state.myUserId)) _scheduleMarkRead();
      case MessageRemoved(:final messageId):
        emit(state.copyWith(
          messages: state.messages.where((m) => m.id != messageId).toList(),
        ));
      case ParticipantsChanged():
        _headerDebounce?.cancel();
        _headerDebounce =
            Timer(const Duration(milliseconds: 400), reloadHeader);
    }
  }

  void _upsert(Message message) {
    final list = [...state.messages];
    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      list[index] = message;
    } else {
      final insertAt = list.indexWhere((m) => m.id < message.id);
      if (insertAt < 0) {
        list.add(message);
      } else {
        list.insert(insertAt, message);
      }
    }
    // Keep reply / edit targets in sync with the latest version.
    final editing = state.editing;
    emit(state.copyWith(
      messages: list,
      clearEditing: editing != null && editing.id == message.id && message.isDeleted,
    ));
  }

  void _scheduleMarkRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 600), () {
      final newest = state.messages.isEmpty ? null : state.messages.first.id;
      _markRead(MarkReadParams(conversationId: _id, messageId: newest));
    });
  }

  // ── Composer ───────────────────────────────────────────────────────────

  void startReply(Message message) =>
      emit(state.copyWith(replyTo: message, clearEditing: true));

  void cancelReply() => emit(state.copyWith(clearReply: true));

  void startEdit(Message message) {
    if (!message.canEdit(state.myUserId)) return;
    emit(state.copyWith(editing: message, clearReply: true));
  }

  void cancelEdit() => emit(state.copyWith(clearEditing: true));

  /// Sends a new message, or saves the edit when one is in progress.
  /// Returns true when the composer should be cleared.
  Future<bool> submit(String text) async {
    if (state.isSending) return false;
    final editing = state.editing;
    emit(state.copyWith(isSending: true, clearActionFailure: true));

    final result = editing != null
        ? await _editMessage(EditMessageParams(message: editing, body: text))
        : await _sendMessage(SendMessageParams(
            conversationId: _id,
            body: text,
            replyToId: state.replyTo?.id,
          ));
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(isSending: false, actionFailure: failure));
        return false;
      },
      (message) {
        emit(state.copyWith(
          isSending: false,
          clearReply: true,
          clearEditing: true,
        ));
        _upsert(message);
        return true;
      },
    );
  }

  // ── Message actions ────────────────────────────────────────────────────

  Future<void> deleteMessage(Message message, {required bool forEveryone}) async {
    final previous = state.messages;
    if (forEveryone) {
      _upsert(Message(
        id: message.id,
        conversationId: message.conversationId,
        createdAt: message.createdAt,
        senderId: message.senderId,
        kind: message.kind,
        replyToId: message.replyToId,
        deletedAt: DateTime.now().toUtc(),
      ));
    } else {
      emit(state.copyWith(
          messages: previous.where((m) => m.id != message.id).toList()));
    }

    final result = await _deleteMessage(DeleteMessageParams(
      messageId: message.id,
      forEveryone: forEveryone,
    ));
    if (isClosed) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(messages: previous, actionFailure: failure));
    }
  }

  // ── Conversation actions ───────────────────────────────────────────────

  Future<void> setMuted(bool muted) async {
    final result = await _setMuted(SetMutedParams(
      conversationId: _id,
      until: muted
          ? DateTime.now().toUtc().add(const Duration(days: 365 * 100))
          : null,
    ));
    if (isClosed) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(actionFailure: failure));
    } else {
      await reloadHeader();
    }
  }

  Future<bool> renameGroup(String title) async {
    final result = await _updateGroup(
        UpdateGroupParams(conversationId: _id, title: title));
    if (isClosed) return false;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(actionFailure: failure));
      return false;
    }
    await reloadHeader();
    return true;
  }

  Future<bool> removeMember(String userId) async {
    final result = await _removeMember(
        MembersParams(conversationId: _id, userIds: [userId]));
    if (isClosed) return false;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(actionFailure: failure));
      return false;
    }
    await reloadHeader();
    return true;
  }

  Future<void> leave() => _closeWith(() => _leave(_id));

  Future<void> deleteConversation() =>
      _closeWith(() => _deleteConversation(_id));

  Future<void> _closeWith(Future<Result<void>> Function() action) async {
    final result = await action();
    if (isClosed) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(actionFailure: failure));
    } else {
      emit(state.copyWith(isClosedForMe: true));
    }
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));

  @override
  Future<void> close() async {
    _markReadDebounce?.cancel();
    _headerDebounce?.cancel();
    await _realtime?.cancel();
    return super.close();
  }
}
