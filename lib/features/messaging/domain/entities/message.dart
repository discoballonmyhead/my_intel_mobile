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

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;
  bool get isSystem => kind == MessageKind.system;
  bool get isFromDeletedAccount => senderId == null && !isSystem;

  bool isMine(String? userId) => userId != null && senderId == userId;

  bool canEdit(String? userId, {DateTime? now}) =>
      isMine(userId) &&
      !isDeleted &&
      !isSystem &&
      (now ?? DateTime.now().toUtc()).difference(createdAt) <
          MessagingPolicy.editWindow;

  bool canDeleteForEveryone(String? userId) => isMine(userId) && !isDeleted;

  String get preview {
    if (removedByModerator) return 'Message removed by moderators';
    if (isDeleted) return 'Message deleted';
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
