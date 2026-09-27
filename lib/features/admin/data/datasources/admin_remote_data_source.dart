import '../../../../core/constants/db_constants.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';

abstract interface class AdminRemoteDataSource {
  Future<Map<String, dynamic>> stats();
  Future<List<Map<String, dynamic>>> users({
    String? search,
    String? role,
    bool? banned,
    int limit,
    int offset,
  });
  Future<Map<String, dynamic>> userDetail(String userId);
  Future<List<Map<String, dynamic>>> osintApplications(
      {String? status, int limit, int offset});
  Future<void> approveOsint(int applicationId, String? note);
  Future<void> declineOsint(int applicationId, String reason);
  Future<void> revokeOsint(String userId, String reason);
  Future<void> grantRole(String userId, String role);
  Future<void> revokeRole(String userId, String role, String? reason);
  Future<int> banUser(String userId,
      {required String reason, String? duration, bool hideContent, int? reportId});
  Future<void> unbanUser(String userId, String? reason);
  Future<void> liftSanction(int sanctionId, String? reason);
  Future<void> deleteAccount(String userId, String reason);
  Future<List<Map<String, dynamic>>> auditLog({
    int limit,
    int offset,
    String? actorId,
    String? targetType,
    String? targetId,
    String? action,
  });
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AdminRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  Future<dynamic> _call(String fn, [Map<String, dynamic>? params]) =>
      runRpc(() async => await _service.rpc<dynamic>(fn, params: params));

  @override
  Future<Map<String, dynamic>> stats() async =>
      asRow(await _call(AdminRpc.stats)) ?? const {};

  @override
  Future<List<Map<String, dynamic>>> users({
    String? search,
    String? role,
    bool? banned,
    int limit = 50,
    int offset = 0,
  }) async =>
      asRows(await _call(AdminRpc.users, {
        'p_search': search,
        'p_role': role,
        'p_banned': banned,
        'p_limit': limit,
        'p_offset': offset,
      }));

  @override
  Future<Map<String, dynamic>> userDetail(String userId) async =>
      asRow(await _call(AdminRpc.userDetail, {'p_user_id': userId})) ??
      const {};

  @override
  Future<List<Map<String, dynamic>>> osintApplications(
          {String? status, int limit = 50, int offset = 0}) async =>
      asRows(await _call(AdminRpc.osintApplications, {
        'p_status': status,
        'p_limit': limit,
        'p_offset': offset,
      }));

  @override
  Future<void> approveOsint(int applicationId, String? note) => _call(
      AdminRpc.approveOsint,
      {'p_application_id': applicationId, 'p_note': note});

  @override
  Future<void> declineOsint(int applicationId, String reason) => _call(
      AdminRpc.declineOsint,
      {'p_application_id': applicationId, 'p_reason': reason});

  @override
  Future<void> revokeOsint(String userId, String reason) =>
      _call(AdminRpc.revokeOsint, {'p_user_id': userId, 'p_reason': reason});

  @override
  Future<void> grantRole(String userId, String role) =>
      _call(AdminRpc.grantRole, {'p_user_id': userId, 'p_role': role});

  @override
  Future<void> revokeRole(String userId, String role, String? reason) =>
      _call(AdminRpc.revokeRole,
          {'p_user_id': userId, 'p_role': role, 'p_reason': reason});

  @override
  Future<int> banUser(String userId,
          {required String reason,
          String? duration,
          bool hideContent = false,
          int? reportId}) async =>
      asInt(await _call(AdminRpc.banUser, {
        'p_user_id': userId,
        'p_reason': reason,
        'p_duration': duration,
        'p_hide_content': hideContent,
        'p_report_id': reportId,
      })) ??
      0;

  @override
  Future<void> unbanUser(String userId, String? reason) =>
      _call(AdminRpc.unbanUser, {'p_user_id': userId, 'p_reason': reason});

  @override
  Future<void> liftSanction(int sanctionId, String? reason) => _call(
      AdminRpc.liftSanction, {'p_sanction_id': sanctionId, 'p_reason': reason});

  @override
  Future<void> deleteAccount(String userId, String reason) =>
      _call(AdminRpc.deleteAccount, {'p_user_id': userId, 'p_reason': reason});

  @override
  Future<List<Map<String, dynamic>>> auditLog({
    int limit = 100,
    int offset = 0,
    String? actorId,
    String? targetType,
    String? targetId,
    String? action,
  }) async =>
      asRows(await _call(AdminRpc.auditLog, {
        'p_limit': limit,
        'p_offset': offset,
        'p_actor_id': actorId,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_action': action,
      }));
}
