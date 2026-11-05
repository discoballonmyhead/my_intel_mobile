import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/message.dart';
import '../models/messaging_models.dart';

/// All writes go through `public.msg_*` RPCs (the `messaging` tables have no
/// insert/update policies). Reads come back as raw rows so the repository can
/// merge profiles in one batch, the same way the feed does.
abstract interface class MessagingRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchInbox({int limit, DateTime? before});
  Future<int> fetchUnreadTotal();
  Future<Map<String, dynamic>> fetchConversation(String conversationId);
  Future<List<MessageModel>> fetchMessages(String conversationId,
      {int? beforeId, int limit});

  Future<String> getOrCreateDirect(String otherUserId);
  Future<String> createGroup(String title, List<String> memberIds);
  Future<void> updateGroup(String conversationId,
      {String? title, String? avatarUrl});
  Future<int> addMembers(String conversationId, List<String> userIds);
  Future<void> removeMember(String conversationId, String userId);
  Future<void> leave(String conversationId);
  Future<void> deleteConversation(String conversationId);

  Future<MessageModel> send({
    required String conversationId,
    String? body,
    List<MessageAttachment> attachments,
    int? replyToId,
  });
  Future<MessageModel> edit(int messageId, String body);
  Future<void> deleteMessage(int messageId, {required bool forEveryone});
  Future<void> markRead(String conversationId, {int? messageId});
  Future<void> setMuted(String conversationId, DateTime? until);

  /// Uploads into the sender's own storage folder; returns the public URL.
  /// [onProgress] gets the share of bytes sent so far (0–1).
  Future<String> uploadAttachment(
      Uint8List bytes, String path, String? contentType,
      {void Function(double sent)? onProgress});

  Stream<ConversationEvent> watchConversation(String conversationId);
  Stream<void> watchInbox(String userId);
}

class MessagingRemoteDataSourceImpl implements MessagingRemoteDataSource {
  MessagingRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<String> uploadAttachment(
      Uint8List bytes, String path, String? contentType,
      {void Function(double sent)? onProgress}) async {
    final bucket = _service.storage.from(StorageBuckets.mintMedia);
    try {
      // A signed upload URL lets us stream the body ourselves and count the
      // bytes as the connection takes them; uploadBinary can't report that.
      final signed = await bucket.createSignedUploadUrl(path);
      final request =
          _ProgressRequest(Uri.parse(signed.signedUrl), bytes, onProgress)
            ..headers.addAll({
              'apikey': Env.supabasePublishableKey,
              'content-type': contentType ?? 'application/octet-stream',
              'cache-control': 'max-age=3600',
              'x-upsert': 'false',
            });
      final client = http.Client();
      try {
        final response = await client.send(request);
        final body = await response.stream.bytesToString();
        if (response.statusCode >= 300) {
          throw ex.ServerException(_uploadError(response.statusCode, body),
              code: '${response.statusCode}');
        }
      } finally {
        client.close();
      }
      return bucket.getPublicUrl(path);
    } on StorageException catch (e) {
      throw ex.ServerException(
          _isOffline(e.message) ? _offline : e.message,
          code: e.statusCode);
    } on http.ClientException catch (e) {
      throw ex.ServerException(_isOffline(e.message)
          ? _offline
          : 'Upload failed. Check your connection and try again.');
    }
  }

  static const _offline =
      'No internet connection. Tap Retry when you’re back online.';

  /// DNS and socket errors read like "Failed host lookup: '…supabase.co'";
  /// show people what it means instead.
  static bool _isOffline(String message) {
    final m = message.toLowerCase();
    return m.contains('host lookup') ||
        m.contains('socketexception') ||
        m.contains('network is unreachable') ||
        m.contains('connection closed') ||
        m.contains('connection reset') ||
        m.contains('connection refused') ||
        m.contains('timed out') ||
        m.contains('offline');
  }

  static String _uploadError(int status, String body) {
    final text = body.toLowerCase();
    if (status == 413 || text.contains('maximum allowed size')) {
      return 'This file is too big to send.';
    }
    if (text.contains('mime type') || text.contains('not supported')) {
      return 'This type of file can’t be sent.';
    }
    return 'Upload failed. Check your connection and try again.';
  }

  String _uniqueTopic(String base) =>
      '$base:${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<List<Map<String, dynamic>>> fetchInbox(
          {int limit = 30, DateTime? before}) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.inbox, params: {
          'p_limit': limit,
          'p_before': before?.toUtc().toIso8601String(),
        });
        return asRows(res);
      });

  @override
  Future<int> fetchUnreadTotal() => runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.unreadTotal);
        return asInt(res) ?? 0;
      });

  @override
  Future<Map<String, dynamic>> fetchConversation(String conversationId) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.conversation,
            params: {'p_conversation_id': conversationId});
        final row = asRow(res);
        if (row == null) {
          throw const ex.NotFoundException('Conversation not found.');
        }
        return row;
      });

  @override
  Future<List<MessageModel>> fetchMessages(String conversationId,
          {int? beforeId, int limit = MessagingPolicy.pageSize}) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.messages, params: {
          'p_conversation_id': conversationId,
          'p_before_id': beforeId,
          'p_limit': limit,
        });
        return asRows(res).map(MessageModel.fromJson).toList();
      });

  @override
  Future<String> getOrCreateDirect(String otherUserId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.getOrCreateDirect,
            params: {'p_other_user_id': otherUserId});
        return res as String;
      });

  @override
  Future<String> createGroup(String title, List<String> memberIds) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.createGroup,
            params: {'p_title': title, 'p_member_ids': memberIds});
        return res as String;
      });

  @override
  Future<void> updateGroup(String conversationId,
          {String? title, String? avatarUrl}) =>
      runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.updateGroup, params: {
          'p_conversation_id': conversationId,
          'p_title': title,
          'p_avatar_url': avatarUrl,
        });
      });

  @override
  Future<int> addMembers(String conversationId, List<String> userIds) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.addMembers,
            params: {
              'p_conversation_id': conversationId,
              'p_user_ids': userIds,
            });
        return asInt(res) ?? 0;
      });

  @override
  Future<void> removeMember(String conversationId, String userId) =>
      runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.removeMember, params: {
          'p_conversation_id': conversationId,
          'p_user_id': userId,
        });
      });

  @override
  Future<void> leave(String conversationId) => runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.leave,
            params: {'p_conversation_id': conversationId});
      });

  @override
  Future<void> deleteConversation(String conversationId) => runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.deleteConversation,
            params: {'p_conversation_id': conversationId});
      });

  @override
  Future<MessageModel> send({
    required String conversationId,
    String? body,
    List<MessageAttachment> attachments = const [],
    int? replyToId,
  }) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.send, params: {
          'p_conversation_id': conversationId,
          'p_body': body,
          'p_attachments': attachments.map((a) => a.toJson()).toList(),
          'p_reply_to_id': replyToId,
        });
        return MessageModel.fromJson(asRow(res)!);
      });

  @override
  Future<MessageModel> edit(int messageId, String body) => runRpc(() async {
        final res = await _service.rpc<dynamic>(MessagingRpc.edit,
            params: {'p_message_id': messageId, 'p_body': body});
        return MessageModel.fromJson(asRow(res)!);
      });

  @override
  Future<void> deleteMessage(int messageId, {required bool forEveryone}) =>
      runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.delete, params: {
          'p_message_id': messageId,
          'p_for_everyone': forEveryone,
        });
      });

  @override
  Future<void> markRead(String conversationId, {int? messageId}) =>
      runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.markRead, params: {
          'p_conversation_id': conversationId,
          'p_message_id': messageId,
        });
      });

  @override
  Future<void> setMuted(String conversationId, DateTime? until) =>
      runRpc(() async {
        await _service.rpc<dynamic>(MessagingRpc.setMuted, params: {
          'p_conversation_id': conversationId,
          'p_until': until?.toUtc().toIso8601String(),
        });
      });

  @override
  Stream<ConversationEvent> watchConversation(String conversationId) {
    final controller = StreamController<ConversationEvent>.broadcast();
    RealtimeChannel? channel;

    controller.onListen = () {
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      );
      channel = _service.channel(_uniqueTopic('messaging:conv:$conversationId'))
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.messaging,
          table: DbTables.messages,
          filter: filter,
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = asInt(payload.oldRecord['id']);
              if (id != null) controller.add(MessageRemoved(id));
              return;
            }
            final row = payload.newRecord;
            if (row.isEmpty) return;
            controller.add(MessageUpserted(MessageModel.fromJson(row)));
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.messaging,
          table: DbTables.participants,
          filter: filter,
          callback: (_) => controller.add(const ParticipantsChanged()),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _service.removeChannel(c);
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<void> watchInbox(String userId) {
    final controller = StreamController<void>.broadcast();
    RealtimeChannel? channel;

    controller.onListen = () {
      channel = _service.channel(_uniqueTopic('messaging:inbox:$userId'))
        // RLS limits these to conversations the user belongs to.
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.messaging,
          table: DbTables.conversations,
          callback: (_) => controller.add(null),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.messaging,
          table: DbTables.participants,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => controller.add(null),
        )
        ..subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _service.removeChannel(c);
      await controller.close();
    };
    return controller.stream;
  }
}

/// A PUT whose body is handed over in 64 KB pieces. The connection pulls each
/// piece only when it has room, so counting them gives real upload progress.
class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(Uri url, this._bytes, this._onProgress) : super('PUT', url);

  final Uint8List _bytes;
  final void Function(double sent)? _onProgress;

  static const _chunk = 64 * 1024;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_pieces());
  }

  @override
  int? get contentLength => _bytes.length;

  @override
  set contentLength(int? value) {}

  Stream<List<int>> _pieces() async* {
    final total = _bytes.length;
    for (var start = 0; start < total; start += _chunk) {
      final end = start + _chunk < total ? start + _chunk : total;
      yield Uint8List.sublistView(_bytes, start, end);
      _onProgress?.call(end / total);
    }
  }
}
