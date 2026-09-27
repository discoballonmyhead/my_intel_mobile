import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

class MessageAttachmentModel extends MessageAttachment {
  const MessageAttachmentModel({required super.url, super.type, super.name});

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) {
    return MessageAttachmentModel(
      url: (json['url'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'file',
      name: json['name'] as String?,
    );
  }
}

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.createdAt,
    super.senderId,
    super.kind,
    super.body,
    super.attachments,
    super.replyToId,
    super.editedAt,
    super.editCount,
    super.deletedAt,
    super.removedByModerator,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    return MessageModel(
      id: asInt(json['id']) ?? 0,
      conversationId: json['conversation_id'] as String,
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      senderId: json['sender_id'] as String?,
      kind: json['kind'] == 'system' ? MessageKind.system : MessageKind.text,
      body: json['body'] as String?,
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map>()
              .map((m) =>
                  MessageAttachmentModel.fromJson(Map<String, dynamic>.from(m)))
              .where((a) => a.url.isNotEmpty)
              .toList()
          : const [],
      replyToId: asInt(json['reply_to_id']),
      editedAt: parseTimestamp(json['edited_at']),
      editCount: asInt(json['edit_count']) ?? 0,
      deletedAt: parseTimestamp(json['deleted_at']),
      removedByModerator: (json['removed_by_moderator'] as bool?) ?? false,
    );
  }
}

class ParticipantModel extends Participant {
  const ParticipantModel({
    required super.userId,
    super.role,
    super.joinedAt,
    super.lastReadMessageId,
    super.profile,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json,
      {Profile? profile}) {
    return ParticipantModel(
      userId: json['user_id'] as String,
      role: ParticipantRole.fromValue(json['role'] as String?),
      joinedAt: parseTimestamp(json['joined_at']),
      lastReadMessageId: asInt(json['last_read_message_id']),
      profile: profile,
    );
  }
}

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.kind,
    super.title,
    super.avatarUrl,
    super.createdBy,
    super.createdAt,
    super.myRole,
    super.mutedUntil,
    super.participants,
  });

  /// User ids of members, so the repository can batch-fetch their profiles.
  static List<String> participantIds(Map<String, dynamic> json) =>
      (json['participants'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((m) => m['user_id'] as String?)
          .whereType<String>()
          .toList();

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, Profile> profiles = const {},
  }) {
    final participants = (json['participants'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) {
      final row = Map<String, dynamic>.from(m);
      return ParticipantModel.fromJson(row,
          profile: profiles[row['user_id'] as String?]);
    }).toList();

    return ConversationModel(
      id: json['id'] as String,
      kind: ConversationKind.fromValue(json['kind'] as String?),
      title: json['title'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: parseTimestamp(json['created_at']),
      myRole: ParticipantRole.fromValue(json['my_role'] as String?),
      mutedUntil: parseTimestamp(json['muted_until']),
      participants: participants,
    );
  }
}

class InboxEntryModel extends InboxEntry {
  const InboxEntryModel({
    required super.conversationId,
    required super.kind,
    required super.lastActivityAt,
    super.title,
    super.avatarUrl,
    super.otherUserId,
    super.otherProfile,
    super.lastMessageId,
    super.lastMessageBody,
    super.lastMessageSenderId,
    super.lastMessageDeleted,
    super.unreadCount,
    super.isMuted,
    super.myRole,
  });

  factory InboxEntryModel.fromJson(Map<String, dynamic> json,
      {Profile? otherProfile}) {
    return InboxEntryModel(
      conversationId: json['conversation_id'] as String,
      kind: ConversationKind.fromValue(json['kind'] as String?),
      lastActivityAt:
          parseTimestamp(json['last_activity_at']) ?? DateTime.now().toUtc(),
      title: json['title'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      otherUserId: json['other_user_id'] as String?,
      otherProfile: otherProfile,
      lastMessageId: asInt(json['last_message_id']),
      lastMessageBody: json['last_message_body'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageDeleted: (json['last_message_deleted'] as bool?) ?? false,
      unreadCount: asInt(json['unread_count']) ?? 0,
      isMuted: (json['is_muted'] as bool?) ?? false,
      myRole: ParticipantRole.fromValue(json['my_role'] as String?),
    );
  }
}
