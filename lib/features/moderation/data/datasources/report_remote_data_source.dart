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
  /// Encrypted message: the reporter's phone supplies the text and the
  /// franking key, the server checks them against the stored tag.
  Future<int> reportEncryptedMessage({
    required int messageId,
    required String reason,
    required String plaintext,
    required String frankingKey,
    String? details,
  });
  Future<List<Map<String, dynamic>>> myReports({int limit, int offset});
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
  Future<int> reportEncryptedMessage({
    required int messageId,
    required String reason,
    required String plaintext,
    required String frankingKey,
    String? details,
  }) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(ReportRpc.reportMessage, params: {
          'p_message_id': messageId,
          'p_reason': reason,
          'p_plaintext': plaintext,
          'p_franking_key': frankingKey,
          'p_details': details,
        });
        return asInt(res) ?? 0;
      });

  @override
  Future<List<Map<String, dynamic>>> myReports({int limit = 50, int offset = 0}) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(ReportRpc.myReports,
          params: {'p_limit': limit, 'p_offset': offset})));
}
