import 'dart:async';

import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/result.dart';
import '../../../e2ee/domain/message_crypto.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_data_source.dart';
import '../models/messaging_models.dart';

/// Profiles live in `identity`, conversations in `messaging`; PostgREST can't
/// embed across schemas, so authors are batch-fetched and merged here.
///
/// End-to-end encryption also happens here, so cubits and pages only ever
/// see plaintext [Message]s: outgoing text is sealed with [MessageCrypto]
/// before it leaves the phone, incoming ciphertext is opened on arrival.
class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl(
    this._remote,
    this._profiles, {
    MessageCrypto? crypto,
    String? Function()? currentUserId,
  })  : _crypto = crypto,
        _me = currentUserId ?? (() => null);

  final MessagingRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;
  final MessageCrypto? _crypto;
  final String? Function() _me;

  /// Members / epoch per conversation, refreshed when members change.
  final Map<String, (DateTime, ConversationKeys, Conversation)> _keys = {};
  static const Duration _keysTtl = Duration(seconds: 30);

  @override
  Future<Result<List<InboxEntry>>> getInbox(
      {int limit = 30, DateTime? before}) {
    return guard(() async {
      final rows = await _remote.fetchInbox(limit: limit, before: before);
      final profiles = await runRpc(() => _profiles
          .profilesByIds(rows.map((r) => r['other_user_id'] as String?)));
      final entries = <InboxEntry>[];
      for (final row in rows) {
        InboxEntry entry = InboxEntryModel.fromJson(row,
            otherProfile: profiles[row['other_user_id'] as String?]);
        if (row['last_message_kind'] == 'e2ee') {
          entry = entry.copyWith(lastMessageBody: await _previewOf(row));
        } else if (row['last_message_kind'] == 'system') {
          entry = entry.copyWith(
              lastMessageBody:
                  row['last_message_body'] == 'e2ee:identity_changed'
                      ? 'Security code changed'
                      : 'Security update');
        }
        entries.add(entry);
      }
      return entries;
    });
  }

  Future<String> _previewOf(Map<String, dynamic> row) async {
    final crypto = _crypto;
    final id = asInt(row['last_message_id']);
    if (crypto == null || id == null) return '🔒 Encrypted message';
    final cached = await crypto.peek(id);
    if (cached != null) return _payloadPreview(cached);
    final env = row['last_message_envelope'];
    final ct = row['last_message_ciphertext'] as String?;
    if (env is! Map || ct == null || !crypto.isReady)
      return '🔒 Encrypted message';
    final opened = await crypto.open(SealedRow(
      messageId: id,
      conversationId: row['conversation_id'] as String,
      senderId: row['last_message_sender_id'] as String?,
      envelope: Map<String, dynamic>.from(env),
      ciphertext: ct,
    ));
    return opened.payload == null
        ? '🔒 Encrypted message'
        : _payloadPreview(opened.payload!);
  }

  String _payloadPreview(MessagePayload p) => p.body.trim().isNotEmpty
      ? p.body.trim()
      : (p.attachments.isNotEmpty ? 'Attachment' : ' ');

  @override
  Future<Result<int>> getUnreadTotal() => guard(_remote.fetchUnreadTotal);

  @override
  Future<Result<Conversation>> getConversation(String conversationId) =>
      guard(() async => (await _loadConversation(conversationId)).$2);

  Future<(ConversationKeys, Conversation)> _loadConversation(
      String conversationId) async {
    final row = await _remote.fetchConversation(conversationId);
    final profiles = await runRpc(
        () => _profiles.profilesByIds(ConversationModel.participantIds(row)));
    final conversation = ConversationModel.fromJson(row, profiles: profiles);
    final me = _me();
    final keys = ConversationKeys(
      conversationId: conversationId,
      isGroup: conversation.isGroup,
      keyEpoch: conversation.keyEpoch,
      isEncrypted: conversation.isEncrypted,
      memberIds: [
        for (final p in conversation.participants)
          if (p.userId != me) p.userId
      ],
      membersWithoutKeys: [
        for (final p in conversation.membersWithoutKeys(me)) p.userId
      ],
    );
    _keys[conversationId] = (DateTime.now(), keys, conversation);
    return (keys, conversation);
  }

  Future<(ConversationKeys, Conversation)> _keysFor(
      String conversationId) async {
    final hit = _keys[conversationId];
    if (hit != null && DateTime.now().difference(hit.$1) < _keysTtl)
      return (hit.$2, hit.$3);
    return _loadConversation(conversationId);
  }

  @override
  Future<Result<List<Message>>> getMessages(
    String conversationId, {
    int? beforeId,
    int limit = MessagingPolicy.pageSize,
  }) =>
      guard(() async {
        final rows = await _remote.fetchMessages(conversationId,
            beforeId: beforeId, limit: limit);
        // open oldest first so ratchet chains advance in order
        final opened = <Message>[];
        for (final m in rows.reversed) {
          opened.add(await _open(m));
        }
        return opened.reversed.toList();
      });

  /// Decrypts an encrypted row (or passes a plain one through).
  Future<Message> _open(Message m) async {
    final crypto = _crypto;
    if (m.isSystem &&
        m.senderId != null &&
        (m.body ?? '').startsWith('e2ee:')) {
      crypto?.forgetIdentity(m.senderId!);
      return m;
    }
    final sealed = m.sealed;
    if (sealed == null || m.isDeleted || crypto == null) return m;
    final result = await crypto.open(SealedRow(
      messageId: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      envelope: sealed.envelope,
      ciphertext: sealed.ciphertext,
    ));
    return switch (result.status) {
      OpenStatus.ok => m.opened(
          body: result.payload!.body,
          attachments: _attachments(result.payload!),
          encryption: MessageEncryption.encrypted),
      OpenStatus.waitingForKey =>
        m.opened(encryption: MessageEncryption.waitingForKey),
      OpenStatus.unavailable =>
        m.opened(encryption: MessageEncryption.unavailable),
      OpenStatus.failed => m.opened(encryption: MessageEncryption.failed),
    };
  }

  List<MessageAttachment> _attachments(MessagePayload p) => [
        for (final a in p.attachments)
          if (a['url'] is String)
            MessageAttachment(
                url: a['url'] as String,
                type: (a['type'] as String?) ?? 'file',
                name: a['name'] as String?),
      ];

  @override
  Future<Result<String>> openDirect(String otherUserId) =>
      guard(() => _remote.getOrCreateDirect(otherUserId));

  @override
  Future<Result<String>> createGroup({
    required String title,
    required List<String> memberIds,
  }) =>
      guard(() => _remote.createGroup(title, memberIds));

  @override
  Future<Result<void>> updateGroup(String conversationId,
          {String? title, String? avatarUrl}) =>
      guard(() => _remote.updateGroup(conversationId,
          title: title, avatarUrl: avatarUrl));

  @override
  Future<Result<int>> addMembers(String conversationId, List<String> userIds) =>
      guard(() async {
        _keys.remove(conversationId);
        return _remote.addMembers(conversationId, userIds);
      });

  @override
  Future<Result<void>> removeMember(String conversationId, String userId) =>
      guard(() async {
        _keys.remove(conversationId);
        await _remote.removeMember(conversationId, userId);
      });

  @override
  Future<Result<void>> leaveConversation(String conversationId) =>
      guard(() => _remote.leave(conversationId));

  @override
  Future<Result<void>> deleteConversation(String conversationId) =>
      guard(() => _remote.deleteConversation(conversationId));

  @override
  Future<Result<Message>> sendMessage({
    required String conversationId,
    String? body,
    List<MessageAttachment> attachments = const [],
    int? replyToId,
  }) =>
      guard(() async {
        final crypto = _crypto;
        final (keys, conversation) = await _keysFor(conversationId);
        final canEncrypt = crypto != null && crypto.isReady;

        // Encrypt whenever everyone can read it. A conversation that has never
        // been encrypted falls back to plaintext while the other person is
        // still on an old app; once encrypted, it never goes back.
        if (!canEncrypt || (!keys.isEncrypted && !keys.everyoneHasKeys)) {
          if (keys.isEncrypted) {
            throw const ex.ValidationException(
                'Secure messaging is still being set up on this phone. Try again in a moment.');
          }
          return _remote.send(
              conversationId: conversationId,
              body: body,
              attachments: attachments,
              replyToId: replyToId);
        }
        if (!keys.isGroup && !keys.everyoneHasKeys) {
          throw ex.ValidationException(
              '${conversation.displayName(_me())} needs to update the app before you can send encrypted messages.');
        }

        final payload = MessagePayload(
          body: body ?? '',
          attachments: [for (final a in attachments) a.toJson()],
        );
        final SealedMessage sealed;
        try {
          sealed = await crypto.seal(keys, payload);
        } on RecipientNotReady {
          _keys.remove(conversationId);
          throw const ex.ValidationException(
              'This person needs to update the app before you can send encrypted messages.');
        }
        final sent = await _remote.sendE2ee(
          conversationId: conversationId,
          ciphertext: sealed.ciphertext,
          envelope: sealed.envelope,
          frankingTag: sealed.frankingTag,
          replyToId: replyToId,
        );
        await crypto.remember(
            sent.id, conversationId, payload, sealed.frankingKey);
        return sent.opened(
            body: body,
            attachments: attachments,
            encryption: MessageEncryption.encrypted);
      });

  @override
  Future<Result<Message>> editMessage(Message message, String body) =>
      guard(() async {
        final crypto = _crypto;
        if (!message.isEncrypted) return _remote.edit(message.id, body);
        if (crypto == null || !crypto.isReady) {
          throw const ex.ValidationException(
              'Secure messaging is still being set up on this phone.');
        }
        final (keys, _) = await _keysFor(message.conversationId);
        final payload = MessagePayload(
            body: body,
            attachments: [for (final a in message.attachments) a.toJson()]);
        final sealed = await crypto.seal(keys, payload);
        final edited = await _remote.editE2ee(message.id,
            ciphertext: sealed.ciphertext,
            envelope: sealed.envelope,
            frankingTag: sealed.frankingTag);
        await crypto.remember(
            message.id, message.conversationId, payload, sealed.frankingKey);
        return edited.opened(
            body: body,
            attachments: message.attachments,
            encryption: MessageEncryption.encrypted);
      });

  @override
  Future<Result<void>> deleteMessage(int messageId,
          {bool forEveryone = false}) =>
      guard(() => _remote.deleteMessage(messageId, forEveryone: forEveryone));

  @override
  Future<Result<void>> markRead(String conversationId, {int? messageId}) =>
      guard(() => _remote.markRead(conversationId, messageId: messageId));

  @override
  Future<Result<void>> setMuted(String conversationId, DateTime? until) =>
      guard(() => _remote.setMuted(conversationId, until));

  @override
  Stream<ConversationEvent> watchConversation(String conversationId) {
    final controller = StreamController<ConversationEvent>();
    final subs = <StreamSubscription<dynamic>>[];
    // one at a time, in arrival order (ratchet state is sequential)
    var queue = Future<void>.value();

    controller.onListen = () {
      subs.add(_remote.watchConversation(conversationId).listen((event) {
        queue = queue.then((_) async {
          switch (event) {
            case MessageUpserted(:final message):
              final opened = await _open(message);
              if (!controller.isClosed) controller.add(MessageUpserted(opened));
            case ParticipantsChanged():
              _keys.remove(conversationId);
              if (!controller.isClosed) controller.add(event);
            default:
              if (!controller.isClosed) controller.add(event);
          }
        }).catchError((Object _) {});
      }, onError: controller.addError));
      final crypto = _crypto;
      if (crypto != null) {
        subs.add(
            crypto.keysArrived.where((c) => c == conversationId).listen((_) {
          if (!controller.isClosed)
            controller.add(const DecryptionKeysArrived());
        }));
      }
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<void> watchInbox(String userId) => _remote.watchInbox(userId);
}
