import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';

abstract interface class ReportRemoteDataSource {
  Future<int> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  });
  Future<List<Map<String, dynamic>>> myReports({int limit, int offset});
  Future<List<Map<String, dynamic>>> queue({
    required String status,
    String? targetType,
    int limit,
    int offset,
  });
  Future<List<Map<String, dynamic>>> forTarget(String type, String id);
  Future<int> claimTarget(String type, String id);
  Future<int> resolveTarget(String type, String id,
      {required String outcome, String? action, String? note});
  Future<void> removePost(int postId, String reason);
  Future<void> restorePost(int postId, String? reason);
  Future<void> setPostVisibility(int postId, String status, String? reason);
  Future<void> removeMessage(int messageId, String reason);
  Future<void> removeComment(int commentId, String reason);
  Future<int> warnUser(String userId, String reason, int? reportId);
  Stream<void> watchReports();
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  ReportRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<int> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReportRpc.report, params: {
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_reason': reason,
          'p_details': details,
        });
        return asInt(res) ?? 0;
      });

  @override
  Future<List<Map<String, dynamic>>> myReports({int limit = 50, int offset = 0}) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(ReportRpc.myReports,
          params: {'p_limit': limit, 'p_offset': offset})));

  @override
  Future<List<Map<String, dynamic>>> queue({
    required String status,
    String? targetType,
    int limit = 50,
    int offset = 0,
  }) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(ReportRpc.queue,
              params: {
                'p_status': status,
                'p_target_type': targetType,
                'p_limit': limit,
                'p_offset': offset,
              })));

  @override
  Future<List<Map<String, dynamic>>> forTarget(String type, String id) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(ReportRpc.forTarget,
          params: {'p_target_type': type, 'p_target_id': id})));

  @override
  Future<int> claimTarget(String type, String id) => runRpc(() async {
        final res = await _service.rpc<dynamic>(ReportRpc.claimTarget,
            params: {'p_target_type': type, 'p_target_id': id});
        return asInt(res) ?? 0;
      });

  @override
  Future<int> resolveTarget(String type, String id,
          {required String outcome, String? action, String? note}) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReportRpc.resolveTarget, params: {
          'p_target_type': type,
          'p_target_id': id,
          'p_outcome': outcome,
          'p_action': action,
          'p_note': note,
        });
        return asInt(res) ?? 0;
      });

  @override
  Future<void> removePost(int postId, String reason) => runRpc(() async {
        await _service.rpc<dynamic>(ReportRpc.removePost,
            params: {'p_post_id': postId, 'p_reason': reason});
      });

  @override
  Future<void> restorePost(int postId, String? reason) => runRpc(() async {
        await _service.rpc<dynamic>(ReportRpc.restorePost,
            params: {'p_post_id': postId, 'p_reason': reason});
      });

  @override
  Future<void> setPostVisibility(int postId, String status, String? reason) =>
      runRpc(() async {
        await _service.rpc<dynamic>(ReportRpc.setPostVisibility, params: {
          'p_post_id': postId,
          'p_status': status,
          'p_reason': reason,
        });
      });

  @override
  Future<void> removeMessage(int messageId, String reason) => runRpc(() async {
        await _service.rpc<dynamic>(ReportRpc.removeMessage,
            params: {'p_message_id': messageId, 'p_reason': reason});
      });

  @override
  Future<void> removeComment(int commentId, String reason) => runRpc(() async {
        await _service.rpc<dynamic>(ReportRpc.removeComment,
            params: {'p_comment_id': commentId, 'p_reason': reason});
      });

  @override
  Future<int> warnUser(String userId, String reason, int? reportId) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReportRpc.warnUser, params: {
          'p_user_id': userId,
          'p_reason': reason,
          'p_report_id': reportId,
        });
        return asInt(res) ?? 0;
      });

  @override
  Stream<void> watchReports() {
    final controller = StreamController<void>.broadcast();
    RealtimeChannel? channel;
    controller.onListen = () {
      channel = _service
          .channel('moderation:reports:${DateTime.now().microsecondsSinceEpoch}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: DbSchemas.moderation,
          table: DbTables.reports,
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
