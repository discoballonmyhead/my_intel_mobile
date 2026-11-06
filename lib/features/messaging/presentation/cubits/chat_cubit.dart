import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/messaging_usecases.dart';

enum ChatStatus { loading, ready, error }

/// A photo, video or file picked in the composer, not uploaded yet.
class PickedChatFile extends Equatable {
  const PickedChatFile({
    required this.bytes,
    required this.type,
    required this.name,
    this.contentType,
  });

  final Uint8List bytes;

  /// 'image' | 'video' | 'file'
  final String type;
  final String name;
  final String? contentType;

  bool get isImage => type == 'image';

  @override
  List<Object?> get props => [name, type, bytes.length];
}

/// A message with attachments that is still uploading, or that failed. Shown
/// at the bottom of the thread until the server copy arrives.
class OutgoingMessage extends Equatable {
  const OutgoingMessage({
    required this.localId,
    required this.files,
    this.body,
    this.replyToId,
    this.uploaded = const [],
    this.progress = 0,
    this.error,
  });

  final int localId;
  final List<PickedChatFile> files;
  final String? body;
  final int? replyToId;

  /// Files already stored, in order; a retry carries on after these.
  final List<MessageAttachment> uploaded;

  /// Share of all the bytes sent so far (0–1).
  final double progress;

  /// Why it wasn't sent; null while sending.
  final String? error;

  bool get failed => error != null;
  int get percent => (progress * 100).round().clamp(0, 100);

  OutgoingMessage copyWith({
    List<MessageAttachment>? uploaded,
    double? progress,
    String? error,
    bool clearError = false,
  }) =>
      OutgoingMessage(
        localId: localId,
        files: files,
        body: body,
        replyToId: replyToId,
        uploaded: uploaded ?? this.uploaded,
        progress: progress ?? this.progress,
        error: clearError ? null : error ?? this.error,
      );

  @override
  List<Object?> get props => [localId, files, body, uploaded, progress, error];
}

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
    this.outgoing = const [],
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

  /// Messages with attachments still uploading, oldest first.
  final List<OutgoingMessage> outgoing;

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

  /// Group picture: the group's letter and the most recent sender who isn't
  /// you, or any other member until someone else has written. The inbox uses
  /// the same rule, so a group looks the same everywhere.
  List<String> get groupAvatarNames {
    final others = conversation?.participants
            .where((p) => p.userId != myUserId)
            .toList() ??
        const [];
    String? partner;
    for (final m in messages) {
      if (m.isSystem || m.senderId == null || m.senderId == myUserId) continue;
      partner = conversation?.participant(m.senderId!)?.displayName;
      if (partner != null) break;
    }
    partner ??= others.isEmpty ? null : others.first.displayName;
    return [title, if (partner != null) partner];
  }

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
    List<OutgoingMessage>? outgoing,
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
      outgoing: outgoing ?? this.outgoing,
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
        outgoing,
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
    UploadMessageAttachment? uploadAttachment,
  })  : _upload = uploadAttachment,
        _getConversation = getConversation,
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
  final UploadMessageAttachment? _upload;
  int _localIds = 0;

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
      emit(state.copyWith(
          status: ChatStatus.error, failure: page.failureOrNull));
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
      case DecryptionKeysArrived():
        _reopenRecent();
    }
  }

  /// Group keys arrived: messages that were waiting for them can be read now.
  Future<void> _reopenRecent() async {
    if (!state.messages
        .any((m) => m.encryption == MessageEncryption.waitingForKey)) return;
    final page = await _getMessages(GetMessagesParams(conversationId: _id));
    if (isClosed) return;
    for (final m in page.valueOrNull ?? const <Message>[]) {
      _upsert(m);
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
      clearEditing:
          editing != null && editing.id == message.id && message.isDeleted,
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

  /// Uploads [files] one by one, then sends them with [text] as the caption.
  /// The message shows a percentage meanwhile; if anything fails it stays in
  /// the thread with Retry and Remove. Returns true once sent.
  Future<bool> sendFiles(List<PickedChatFile> files, String text) async {
    if (files.isEmpty || _upload == null) return false;
    final caption = text.trim();
    final outgoing = OutgoingMessage(
      localId: ++_localIds,
      files: files,
      body: caption.isEmpty ? null : caption,
      replyToId: state.replyTo?.id,
    );
    emit(state
        .copyWith(outgoing: [...state.outgoing, outgoing], clearReply: true));
    return _deliver(outgoing.localId);
  }

  /// Tries a failed message again, keeping the files that already went up.
  Future<bool> retryOutgoing(int localId) {
    final o = _outgoing(localId);
    if (o == null || !o.failed) return Future.value(false);
    _replaceOutgoing(o.copyWith(clearError: true));
    return _deliver(localId);
  }

  void removeOutgoing(int localId) => emit(state.copyWith(
      outgoing: state.outgoing.where((o) => o.localId != localId).toList()));

  OutgoingMessage? _outgoing(int localId) {
    for (final o in state.outgoing) {
      if (o.localId == localId) return o;
    }
    return null;
  }

  void _replaceOutgoing(OutgoingMessage next) => emit(state.copyWith(outgoing: [
        for (final o in state.outgoing) o.localId == next.localId ? next : o
      ]));

  Future<bool> _deliver(int localId) async {
    final upload = _upload!;
    var o = _outgoing(localId);
    if (o == null) return false;
    final files = o.files;
    final total = files.fold<int>(0, (sum, f) => sum + f.bytes.length);
    final uploaded = [...o.uploaded];

    for (var i = uploaded.length; i < files.length; i++) {
      final file = files[i];
      final before =
          files.take(i).fold<int>(0, (sum, f) => sum + f.bytes.length);
      var lastShown = -1;
      final result = await upload(UploadAttachmentParams(
        bytes: file.bytes,
        type: file.type,
        fileName: file.name,
        contentType: file.contentType,
        onProgress: (sent) {
          final overall = (before + sent * file.bytes.length) / total;
          // Repaint at most once per percent.
          final pct = (overall * 100).floor();
          if (pct == lastShown || isClosed) return;
          lastShown = pct;
          final current = _outgoing(localId);
          if (current != null)
            _replaceOutgoing(current.copyWith(progress: overall));
        },
      ));
      if (isClosed) return false;
      final attachment = result.valueOrNull;
      o = _outgoing(localId);
      if (o == null) return false; // removed while uploading
      if (attachment == null) {
        _replaceOutgoing(o.copyWith(
            uploaded: uploaded,
            error: result.failureOrNull?.message ?? 'Upload failed.'));
        return false;
      }
      uploaded.add(attachment);
      _replaceOutgoing(o.copyWith(uploaded: uploaded));
    }

    final sent = await _sendMessage(SendMessageParams(
      conversationId: _id,
      body: o!.body,
      attachments: uploaded,
      replyToId: o.replyToId,
    ));
    if (isClosed) return false;
    final message = sent.valueOrNull;
    if (message == null) {
      final current = _outgoing(localId);
      if (current != null) {
        _replaceOutgoing(current.copyWith(
            uploaded: uploaded,
            progress: 1,
            error: sent.failureOrNull?.message ?? 'Couldn’t send.'));
      }
      return false;
    }
    _upsert(message);
    removeOutgoing(localId);
    return true;
  }

  // ── Message actions ────────────────────────────────────────────────────

  Future<void> deleteMessage(Message message,
      {required bool forEveryone}) async {
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

  Future<void> setMuted(bool muted) =>
      muteFor(muted ? const Duration(days: 365 * 100) : null);

  /// Mutes for [duration], or unmutes when it's null.
  Future<void> muteFor(Duration? duration) async {
    final result = await _setMuted(SetMutedParams(
      conversationId: _id,
      until: duration == null ? null : DateTime.now().toUtc().add(duration),
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
