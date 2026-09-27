import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_data_source.dart';
import '../models/messaging_models.dart';

/// Profiles live in `identity`, conversations in `messaging`; PostgREST can't
/// embed across schemas, so authors are batch-fetched and merged here.
class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl(this._remote, this._profiles);

  final MessagingRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

  @override
  Future<Result<List<InboxEntry>>> getInbox({int limit = 30, DateTime? before}) {
    return guard(() async {
      final rows = await _remote.fetchInbox(limit: limit, before: before);
      final profiles = await runRpc(() => _profiles
          .profilesByIds(rows.map((r) => r['other_user_id'] as String?)));
      return rows
          .map((row) => InboxEntryModel.fromJson(
                row,
                otherProfile: profiles[row['other_user_id'] as String?],
              ))
          .toList();
    });
  }

  @override
  Future<Result<int>> getUnreadTotal() => guard(_remote.fetchUnreadTotal);

  @override
  Future<Result<Conversation>> getConversation(String conversationId) {
    return guard(() async {
      final row = await _remote.fetchConversation(conversationId);
      final profiles = await runRpc(() =>
          _profiles.profilesByIds(ConversationModel.participantIds(row)));
      return ConversationModel.fromJson(row, profiles: profiles);
    });
  }

  @override
  Future<Result<List<Message>>> getMessages(
    String conversationId, {
    int? beforeId,
    int limit = MessagingPolicy.pageSize,
  }) =>
      guard(() => _remote.fetchMessages(conversationId,
          beforeId: beforeId, limit: limit));

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
      guard(() => _remote.addMembers(conversationId, userIds));

  @override
  Future<Result<void>> removeMember(String conversationId, String userId) =>
      guard(() => _remote.removeMember(conversationId, userId));

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
      guard(() => _remote.send(
            conversationId: conversationId,
            body: body,
            attachments: attachments,
            replyToId: replyToId,
          ));

  @override
  Future<Result<Message>> editMessage(int messageId, String body) =>
      guard(() => _remote.edit(messageId, body));

  @override
  Future<Result<void>> deleteMessage(int messageId, {bool forEveryone = false}) =>
      guard(() => _remote.deleteMessage(messageId, forEveryone: forEveryone));

  @override
  Future<Result<void>> markRead(String conversationId, {int? messageId}) =>
      guard(() => _remote.markRead(conversationId, messageId: messageId));

  @override
  Future<Result<void>> setMuted(String conversationId, DateTime? until) =>
      guard(() => _remote.setMuted(conversationId, until));

  @override
  Stream<ConversationEvent> watchConversation(String conversationId) =>
      _remote.watchConversation(conversationId);

  @override
  Stream<void> watchInbox(String userId) => _remote.watchInbox(userId);
}
