import '../../../../core/utils/result.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class MessagingRepository {
  Future<Result<List<InboxEntry>>> getInbox({int limit = 30, DateTime? before});
  Future<Result<int>> getUnreadTotal();
  Future<Result<Conversation>> getConversation(String conversationId);

  /// Newest first. Pass [beforeId] to page backwards.
  Future<Result<List<Message>>> getMessages(
    String conversationId, {
    int? beforeId,
    int limit = 50,
  });

  /// Returns the conversation id (existing or newly created).
  Future<Result<String>> openDirect(String otherUserId);
  Future<Result<String>> createGroup({
    required String title,
    required List<String> memberIds,
  });
  Future<Result<void>> updateGroup(
    String conversationId, {
    String? title,
    String? avatarUrl,
  });
  Future<Result<int>> addMembers(String conversationId, List<String> userIds);
  Future<Result<void>> removeMember(String conversationId, String userId);
  Future<Result<void>> leaveConversation(String conversationId);

  /// Clears the conversation for the current user only.
  Future<Result<void>> deleteConversation(String conversationId);

  Future<Result<Message>> sendMessage({
    required String conversationId,
    String? body,
    List<MessageAttachment> attachments = const [],
    int? replyToId,
  });
  Future<Result<Message>> editMessage(int messageId, String body);
  Future<Result<void>> deleteMessage(int messageId, {bool forEveryone = false});
  Future<Result<void>> markRead(String conversationId, {int? messageId});
  Future<Result<void>> setMuted(String conversationId, DateTime? until);

  /// Live inserts / edits / deletes in one conversation, plus read receipts.
  Stream<ConversationEvent> watchConversation(String conversationId);

  /// Ticks whenever any of the user's conversations change.
  Stream<void> watchInbox(String userId);
}
