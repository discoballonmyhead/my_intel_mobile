import 'package:equatable/equatable.dart';

/// What the encryption layer needs to know about a conversation to seal a
/// message for it.
class ConversationKeys extends Equatable {
  const ConversationKeys({
    required this.conversationId,
    required this.isGroup,
    required this.keyEpoch,
    required this.memberIds,
    this.isEncrypted = false,
    this.membersWithoutKeys = const [],
  });

  final String conversationId;
  final bool isGroup;

  /// Bumps whenever someone joins or leaves a group (rotate sender keys).
  final int keyEpoch;

  /// Everyone else in the conversation.
  final List<String> memberIds;

  /// True once the first encrypted message was sent (no plaintext after that).
  final bool isEncrypted;

  /// Members on an old app version who have no keys yet.
  final List<String> membersWithoutKeys;

  bool get everyoneHasKeys => membersWithoutKeys.isEmpty;

  @override
  List<Object?> get props => [conversationId, isGroup, keyEpoch, memberIds, isEncrypted, membersWithoutKeys];
}

/// What travels inside the ciphertext.
class MessagePayload extends Equatable {
  const MessagePayload({this.body = '', this.attachments = const []});

  final String body;
  final List<Map<String, dynamic>> attachments;

  Map<String, dynamic> toJson() => {
        'b': body,
        if (attachments.isNotEmpty) 'a': attachments,
      };

  factory MessagePayload.fromJson(Map<String, dynamic> j) => MessagePayload(
        body: (j['b'] as String?) ?? '',
        attachments: [
          for (final a in (j['a'] as List?) ?? const [])
            if (a is Map) Map<String, dynamic>.from(a),
        ],
      );

  @override
  List<Object?> get props => [body, attachments];
}

class SealedMessage {
  const SealedMessage({required this.ciphertext, required this.envelope, required this.frankingTag, required this.frankingKey});
  final String ciphertext;
  final Map<String, dynamic> envelope;
  final String frankingTag;

  /// Kept on this phone so the message can be reported later.
  final String frankingKey;
}

enum OpenStatus {
  ok,

  /// Group message whose sender key hasn't arrived yet (it was requested).
  waitingForKey,

  /// Sent before this phone had its keys (e.g. before a restore).
  unavailable,

  /// Tampered with, or keys don't match.
  failed,
}

class OpenedMessage {
  const OpenedMessage(this.status, {this.payload});
  final OpenStatus status;
  final MessagePayload? payload;
}

/// The raw encrypted fields of a stored message.
class SealedRow {
  const SealedRow({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.envelope,
    required this.ciphertext,
  });
  final int messageId;
  final String conversationId;
  final String? senderId;
  final Map<String, dynamic> envelope;
  final String ciphertext;
}

/// Thrown by [MessageCrypto.seal] when someone can't receive encrypted
/// messages yet (they haven't opened an updated app).
class RecipientNotReady implements Exception {
  const RecipientNotReady(this.userIds);
  final List<String> userIds;
}

/// Messaging only depends on this; the Signal-style implementation lives in
/// `features/e2ee/data/e2ee_service.dart`.
abstract interface class MessageCrypto {
  /// Keys exist on this phone and are registered.
  bool get isReady;

  Future<SealedMessage> seal(ConversationKeys conversation, MessagePayload payload);

  /// Remember what we sent (we can't decrypt our own ratchet messages later).
  Future<void> remember(int messageId, String conversationId, MessagePayload payload, String frankingKey);

  Future<OpenedMessage> open(SealedRow row);

  /// Cached plaintext only (no decryption), e.g. for previews.
  Future<MessagePayload?> peek(int messageId);

  /// A contact set up a new phone / new keys: look them up again.
  void forgetIdentity(String userId);

  /// Fires when new sender keys arrived, so waiting group messages can be
  /// opened again.
  Stream<String> get keysArrived;
}

/// Lets a report carry the decrypted text + franking key (moderation).
abstract interface class MessageEvidenceSource {
  Future<({String plaintext, String frankingKey})?> evidenceFor(int messageId);
}
