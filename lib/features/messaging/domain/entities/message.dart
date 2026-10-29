import 'package:equatable/equatable.dart';

/// Server rules the UI mirrors so it can hide actions that would be rejected.
class MessagingPolicy {
  const MessagingPolicy._();

  /// Must match `v_window` in `public.msg_edit`.
  static const Duration editWindow = Duration(minutes: 15);
  static const int maxBodyLength = 4000;
  static const int pageSize = 50;
}

enum MessageKind { text, system }

/// End-to-end encryption state of one message (migration 18).
enum MessageEncryption {
  /// Sent before the conversation was encrypted (old app).
  none,

  /// Decrypted on this phone.
  encrypted,

  /// Group message whose key is on its way.
  waitingForKey,

  /// Sent before this phone had its keys (e.g. before a restore).
  unavailable,

  /// Tampered with, or the keys don't match.
  failed,
}

/// The encrypted form as stored by the server (never shown).
class SealedContent extends Equatable {
  const SealedContent(
      {required this.envelope, required this.ciphertext, this.frankingTag});
  final Map<String, dynamic> envelope;
  final String ciphertext;
  final String? frankingTag;

  @override
  List<Object?> get props => [ciphertext];
}

class MessageAttachment extends Equatable {
  const MessageAttachment({required this.url, this.type = 'file', this.name});

  final String url;

  /// 'image' | 'video' | 'file'
  final String type;
  final String? name;

  bool get isImage => type == 'image';

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
        if (name != null) 'name': name,
      };

  @override
  List<Object?> get props => [url, type, name];
}

/// A row of `messaging.messages`.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.createdAt,
    this.senderId,
    this.kind = MessageKind.text,
    this.body,
    this.attachments = const [],
    this.replyToId,
    this.editedAt,
    this.editCount = 0,
    this.deletedAt,
    this.removedByModerator = false,
    this.encryption = MessageEncryption.none,
    this.sealed,
  });

  final int id;
  final String conversationId;
  final DateTime createdAt;

  /// Null once the sender deleted their account.
  final String? senderId;
  final MessageKind kind;
  final String? body;
  final List<MessageAttachment> attachments;
  final int? replyToId;
  final DateTime? editedAt;
  final int editCount;
  final DateTime? deletedAt;
  final bool removedByModerator;
  final MessageEncryption encryption;

  /// Present on encrypted messages until (and after) they are opened.
  final SealedContent? sealed;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;
  bool get isSystem => kind == MessageKind.system;
  bool get isFromDeletedAccount => senderId == null && !isSystem;
  bool get isEncrypted => encryption != MessageEncryption.none;
  bool get isReadable =>
      encryption == MessageEncryption.none ||
      encryption == MessageEncryption.encrypted;

  /// Hidden system notes (a contact restored their phone).
  bool get isSilentSystem => isSystem && body == 'e2ee:device_changed';

  /// Same message with decrypted content (or a status).
  Message opened(
          {String? body,
          List<MessageAttachment>? attachments,
          required MessageEncryption encryption}) =>
      Message(
        id: id,
        conversationId: conversationId,
        createdAt: createdAt,
        senderId: senderId,
        kind: kind,
        body: body ?? this.body,
        attachments: attachments ?? this.attachments,
        replyToId: replyToId,
        editedAt: editedAt,
        editCount: editCount,
        deletedAt: deletedAt,
        removedByModerator: removedByModerator,
        encryption: encryption,
        sealed: sealed,
      );

  bool isMine(String? userId) => userId != null && senderId == userId;

  bool canEdit(String? userId, {DateTime? now}) =>
      isMine(userId) &&
      !isDeleted &&
      !isSystem &&
      isReadable &&
      (now ?? DateTime.now().toUtc()).difference(createdAt) <
          MessagingPolicy.editWindow;

  bool canDeleteForEveryone(String? userId) => isMine(userId) && !isDeleted;

  String get preview {
    if (removedByModerator) return 'Message removed by moderators';
    if (isDeleted) return 'Message deleted';
    if (isSystem && body == 'e2ee:identity_changed')
      return 'Security code changed';
    if (isSilentSystem) return '';
    switch (encryption) {
      case MessageEncryption.waitingForKey:
        return 'Waiting for this message…';
      case MessageEncryption.unavailable:
        return 'Encrypted message (not on this phone)';
      case MessageEncryption.failed:
        return 'Couldn’t decrypt this message';
      case MessageEncryption.none || MessageEncryption.encrypted:
        break;
    }
    final text = body?.trim() ?? '';
    if (text.isNotEmpty) return text;
    if (attachments.isNotEmpty) {
      return attachments.first.isImage ? 'Photo' : 'Attachment';
    }
    return '';
  }

  @override
  List<Object?> get props => [
        id,
        body,
        attachments,
        editedAt,
        editCount,
        deletedAt,
        removedByModerator,
        senderId,
        encryption,
      ];
}

/// Realtime changes to one conversation.
sealed class ConversationEvent {
  const ConversationEvent();
}

/// Insert or update (edit, delete-for-everyone, moderator removal).
class MessageUpserted extends ConversationEvent {
  const MessageUpserted(this.message);
  final Message message;
}

/// Hard delete (conversation purge cascades).
class MessageRemoved extends ConversationEvent {
  const MessageRemoved(this.messageId);
  final int messageId;
}

/// Someone read, joined or left.
class ParticipantsChanged extends ConversationEvent {
  const ParticipantsChanged();
}

/// Keys for waiting group messages arrived: open them again.
class DecryptionKeysArrived extends ConversationEvent {
  const DecryptionKeysArrived();
}
