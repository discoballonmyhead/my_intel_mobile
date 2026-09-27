import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';
import '../repositories/messaging_repository.dart';

// ── Reads ──────────────────────────────────────────────────────────────────

class GetInboxParams {
  const GetInboxParams({this.limit = 30, this.before});
  final int limit;
  final DateTime? before;
}

class GetInbox implements UseCase<List<InboxEntry>, GetInboxParams> {
  const GetInbox(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<List<InboxEntry>>> call(GetInboxParams params) =>
      _repository.getInbox(limit: params.limit, before: params.before);
}

class GetUnreadTotal implements UseCase<int, NoParams> {
  const GetUnreadTotal(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<int>> call(NoParams params) => _repository.getUnreadTotal();
}

class GetConversation implements UseCase<Conversation, String> {
  const GetConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<Conversation>> call(String conversationId) =>
      _repository.getConversation(conversationId);
}

class GetMessagesParams {
  const GetMessagesParams({
    required this.conversationId,
    this.beforeId,
    this.limit = MessagingPolicy.pageSize,
  });
  final String conversationId;
  final int? beforeId;
  final int limit;
}

class GetMessages implements UseCase<List<Message>, GetMessagesParams> {
  const GetMessages(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<List<Message>>> call(GetMessagesParams params) =>
      _repository.getMessages(
        params.conversationId,
        beforeId: params.beforeId,
        limit: params.limit,
      );
}

// ── Conversations ──────────────────────────────────────────────────────────

class OpenDirectConversation implements UseCase<String, String> {
  const OpenDirectConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<String>> call(String otherUserId) =>
      _repository.openDirect(otherUserId);
}

class CreateGroupParams {
  const CreateGroupParams({required this.title, required this.memberIds});
  final String title;
  final List<String> memberIds;
}

class CreateGroupConversation implements UseCase<String, CreateGroupParams> {
  const CreateGroupConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<String>> call(CreateGroupParams params) async {
    if (params.memberIds.isEmpty) {
      return const Err(ValidationFailure('Add at least one other person.'));
    }
    if (params.title.trim().length > 100) {
      return const Err(ValidationFailure('Group names are limited to 100 characters.'));
    }
    return _repository.createGroup(
      title: params.title.trim(),
      memberIds: params.memberIds.toSet().toList(),
    );
  }
}

class UpdateGroupParams {
  const UpdateGroupParams({
    required this.conversationId,
    this.title,
    this.avatarUrl,
  });
  final String conversationId;
  final String? title;
  final String? avatarUrl;
}

class UpdateGroup implements UseCase<void, UpdateGroupParams> {
  const UpdateGroup(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(UpdateGroupParams params) => _repository.updateGroup(
        params.conversationId,
        title: params.title,
        avatarUrl: params.avatarUrl,
      );
}

class MembersParams {
  const MembersParams({required this.conversationId, required this.userIds});
  final String conversationId;
  final List<String> userIds;
}

class AddGroupMembers implements UseCase<int, MembersParams> {
  const AddGroupMembers(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<int>> call(MembersParams params) =>
      _repository.addMembers(params.conversationId, params.userIds);
}

class RemoveGroupMember implements UseCase<void, MembersParams> {
  const RemoveGroupMember(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(MembersParams params) async {
    if (params.userIds.length != 1) {
      return const Err(ValidationFailure('Remove one member at a time.'));
    }
    return _repository.removeMember(params.conversationId, params.userIds.first);
  }
}

class LeaveConversation implements UseCase<void, String> {
  const LeaveConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(String conversationId) =>
      _repository.leaveConversation(conversationId);
}

class DeleteConversation implements UseCase<void, String> {
  const DeleteConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(String conversationId) =>
      _repository.deleteConversation(conversationId);
}

class SetMutedParams {
  const SetMutedParams({required this.conversationId, this.until});
  final String conversationId;

  /// Null unmutes.
  final DateTime? until;
}

class SetConversationMuted implements UseCase<void, SetMutedParams> {
  const SetConversationMuted(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(SetMutedParams params) =>
      _repository.setMuted(params.conversationId, params.until);
}

// ── Messages ───────────────────────────────────────────────────────────────

class SendMessageParams {
  const SendMessageParams({
    required this.conversationId,
    this.body,
    this.attachments = const [],
    this.replyToId,
  });
  final String conversationId;
  final String? body;
  final List<MessageAttachment> attachments;
  final int? replyToId;
}

class SendMessage implements UseCase<Message, SendMessageParams> {
  const SendMessage(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<Message>> call(SendMessageParams params) async {
    final body = params.body?.trim() ?? '';
    if (body.isEmpty && params.attachments.isEmpty) {
      return const Err(ValidationFailure('Message is empty.'));
    }
    if (body.length > MessagingPolicy.maxBodyLength) {
      return const Err(ValidationFailure('Messages are limited to 4000 characters.'));
    }
    return _repository.sendMessage(
      conversationId: params.conversationId,
      body: body.isEmpty ? null : body,
      attachments: params.attachments,
      replyToId: params.replyToId,
    );
  }
}

class EditMessageParams {
  const EditMessageParams({required this.message, required this.body});
  final Message message;
  final String body;
}

class EditMessage implements UseCase<Message, EditMessageParams> {
  const EditMessage(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<Message>> call(EditMessageParams params) async {
    final body = params.body.trim();
    if (body.isEmpty && params.message.attachments.isEmpty) {
      return const Err(ValidationFailure('Message is empty.'));
    }
    if (body.length > MessagingPolicy.maxBodyLength) {
      return const Err(ValidationFailure('Messages are limited to 4000 characters.'));
    }
    if (DateTime.now().toUtc().difference(params.message.createdAt) >=
        MessagingPolicy.editWindow) {
      return const Err(ValidationFailure('Messages can only be edited for 15 minutes.'));
    }
    return _repository.editMessage(params.message.id, body);
  }
}

class DeleteMessageParams {
  const DeleteMessageParams({required this.messageId, this.forEveryone = false});
  final int messageId;
  final bool forEveryone;
}

class DeleteMessage implements UseCase<void, DeleteMessageParams> {
  const DeleteMessage(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(DeleteMessageParams params) => _repository
      .deleteMessage(params.messageId, forEveryone: params.forEveryone);
}

class MarkReadParams {
  const MarkReadParams({required this.conversationId, this.messageId});
  final String conversationId;
  final int? messageId;
}

class MarkConversationRead implements UseCase<void, MarkReadParams> {
  const MarkConversationRead(this._repository);
  final MessagingRepository _repository;

  @override
  Future<Result<void>> call(MarkReadParams params) => _repository
      .markRead(params.conversationId, messageId: params.messageId);
}

// ── Realtime ───────────────────────────────────────────────────────────────

class WatchConversation implements StreamUseCase<ConversationEvent, String> {
  const WatchConversation(this._repository);
  final MessagingRepository _repository;

  @override
  Stream<ConversationEvent> call(String conversationId) =>
      _repository.watchConversation(conversationId);
}

class WatchInbox implements StreamUseCase<void, String> {
  const WatchInbox(this._repository);
  final MessagingRepository _repository;

  @override
  Stream<void> call(String userId) => _repository.watchInbox(userId);
}
