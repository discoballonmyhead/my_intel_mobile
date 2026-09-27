import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

enum ConversationKind {
  direct,
  group;

  static ConversationKind fromValue(String? value) =>
      value == 'group' ? ConversationKind.group : ConversationKind.direct;
}

enum ParticipantRole {
  owner,
  admin,
  member;

  static ParticipantRole fromValue(String? value) => switch (value) {
        'owner' => ParticipantRole.owner,
        'admin' => ParticipantRole.admin,
        _ => ParticipantRole.member,
      };

  bool get canManage => this == owner || this == admin;
}

class Participant extends Equatable {
  const Participant({
    required this.userId,
    this.role = ParticipantRole.member,
    this.joinedAt,
    this.lastReadMessageId,
    this.profile,
  });

  final String userId;
  final ParticipantRole role;
  final DateTime? joinedAt;
  final int? lastReadMessageId;
  final Profile? profile;

  String get displayName => profile?.username ?? 'unknown';

  Participant withProfile(Profile? profile) => Participant(
        userId: userId,
        role: role,
        joinedAt: joinedAt,
        lastReadMessageId: lastReadMessageId,
        profile: profile,
      );

  @override
  List<Object?> get props => [userId, role, lastReadMessageId, profile];
}

/// Header + members for the chat screen (`msg_get_conversation`).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.kind,
    this.title,
    this.avatarUrl,
    this.createdBy,
    this.createdAt,
    this.myRole = ParticipantRole.member,
    this.mutedUntil,
    this.participants = const [],
  });

  final String id;
  final ConversationKind kind;
  final String? title;
  final String? avatarUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final ParticipantRole myRole;
  final DateTime? mutedUntil;
  final List<Participant> participants;

  bool get isGroup => kind == ConversationKind.group;

  bool get isMuted =>
      mutedUntil != null && mutedUntil!.isAfter(DateTime.now().toUtc());

  Participant? other(String? myUserId) {
    for (final p in participants) {
      if (p.userId != myUserId) return p;
    }
    return null;
  }

  /// Group title, or the other person's username for a DM.
  String displayName(String? myUserId) {
    if (isGroup) {
      final t = title?.trim() ?? '';
      if (t.isNotEmpty) return t;
      final names = participants
          .where((p) => p.userId != myUserId)
          .map((p) => p.displayName)
          .take(3)
          .join(', ');
      return names.isEmpty ? 'Group' : names;
    }
    return other(myUserId)?.displayName ?? 'Deleted user';
  }

  Participant? participant(String? userId) {
    for (final p in participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [id, kind, title, avatarUrl, myRole, mutedUntil, participants];
}

/// One row of the inbox (`msg_get_inbox`).
class InboxEntry extends Equatable {
  const InboxEntry({
    required this.conversationId,
    required this.kind,
    required this.lastActivityAt,
    this.title,
    this.avatarUrl,
    this.otherUserId,
    this.otherProfile,
    this.lastMessageId,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageDeleted = false,
    this.unreadCount = 0,
    this.isMuted = false,
    this.myRole = ParticipantRole.member,
  });

  final String conversationId;
  final ConversationKind kind;
  final DateTime lastActivityAt;
  final String? title;
  final String? avatarUrl;
  final String? otherUserId;
  final Profile? otherProfile;
  final int? lastMessageId;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final bool lastMessageDeleted;
  final int unreadCount;
  final bool isMuted;
  final ParticipantRole myRole;

  bool get isGroup => kind == ConversationKind.group;
  bool get hasUnread => unreadCount > 0;

  String get displayName {
    if (isGroup) {
      final t = title?.trim() ?? '';
      return t.isEmpty ? 'Group' : t;
    }
    return otherProfile?.username ??
        (otherUserId == null ? 'Deleted user' : 'unknown');
  }

  String preview(String? myUserId) {
    if (lastMessageId == null) return 'No messages yet';
    final text = lastMessageDeleted
        ? 'Message deleted'
        : (lastMessageBody?.trim().isNotEmpty ?? false)
            ? lastMessageBody!.trim()
            : 'Attachment';
    return lastMessageSenderId != null && lastMessageSenderId == myUserId
        ? 'You: $text'
        : text;
  }

  InboxEntry copyWith({int? unreadCount, bool? isMuted}) => InboxEntry(
        conversationId: conversationId,
        kind: kind,
        lastActivityAt: lastActivityAt,
        title: title,
        avatarUrl: avatarUrl,
        otherUserId: otherUserId,
        otherProfile: otherProfile,
        lastMessageId: lastMessageId,
        lastMessageBody: lastMessageBody,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageDeleted: lastMessageDeleted,
        unreadCount: unreadCount ?? this.unreadCount,
        isMuted: isMuted ?? this.isMuted,
        myRole: myRole,
      );

  @override
  List<Object?> get props => [
        conversationId,
        lastActivityAt,
        title,
        otherProfile,
        lastMessageId,
        lastMessageBody,
        lastMessageDeleted,
        unreadCount,
        isMuted,
      ];
}
