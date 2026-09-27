import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/result.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';
import '../models/admin_models.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._remote, this._profiles);

  final AdminRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

  /// Postgres accepts "<n> seconds" for an interval parameter.
  static String _interval(Duration d) => '${d.inSeconds} seconds';

  @override
  Future<Result<AdminStats>> getStats() =>
      guard(() async => AdminStatsModel.fromJson(await _remote.stats()));

  @override
  Future<Result<List<AdminUser>>> getUsers({
    String? search,
    AppRole? role,
    bool? banned,
    int limit = 50,
    int offset = 0,
  }) =>
      guard(() async {
        final rows = await _remote.users(
          search: search,
          role: role?.value,
          banned: banned,
          limit: limit,
          offset: offset,
        );
        return rows.map(AdminUserModel.fromJson).toList();
      });

  @override
  Future<Result<AdminUserDetail>> getUserDetail(String userId) =>
      guard(() async {
        final json = await _remote.userDetail(userId);
        final actors = await runRpc(() =>
            _profiles.profilesByIds(AdminUserDetailModel.auditActorIds(json)));
        return AdminUserDetailModel.fromJson(json, actors: actors);
      });

  @override
  Future<Result<List<OsintApplicationReview>>> getOsintApplications({
    String? status,
    int limit = 50,
    int offset = 0,
  }) =>
      guard(() async {
        final rows = await _remote.osintApplications(
            status: status, limit: limit, offset: offset);
        return rows.map(OsintApplicationReviewModel.fromJson).toList();
      });

  @override
  Future<Result<void>> approveOsint(int applicationId, {String? note}) =>
      guard(() => _remote.approveOsint(applicationId, note));

  @override
  Future<Result<void>> declineOsint(int applicationId, String reason) =>
      guard(() => _remote.declineOsint(applicationId, reason));

  @override
  Future<Result<void>> revokeOsint(String userId, String reason) =>
      guard(() => _remote.revokeOsint(userId, reason));

  @override
  Future<Result<void>> grantRole(String userId, AppRole role) =>
      guard(() => _remote.grantRole(userId, role.value));

  @override
  Future<Result<void>> revokeRole(String userId, AppRole role, {String? reason}) =>
      guard(() => _remote.revokeRole(userId, role.value, reason));

  @override
  Future<Result<int>> banUser(
    String userId, {
    required String reason,
    Duration? duration,
    bool hideContent = false,
    int? reportId,
  }) =>
      guard(() => _remote.banUser(
            userId,
            reason: reason,
            duration: duration == null ? null : _interval(duration),
            hideContent: hideContent,
            reportId: reportId,
          ));

  @override
  Future<Result<void>> unbanUser(String userId, {String? reason}) =>
      guard(() => _remote.unbanUser(userId, reason));

  @override
  Future<Result<void>> liftSanction(int sanctionId, {String? reason}) =>
      guard(() => _remote.liftSanction(sanctionId, reason));

  @override
  Future<Result<void>> deleteAccount(String userId, String reason) =>
      guard(() => _remote.deleteAccount(userId, reason));

  @override
  Future<Result<List<AuditEntry>>> getAuditLog({
    int limit = 100,
    int offset = 0,
    String? actorId,
    String? targetType,
    String? targetId,
    String? action,
  }) =>
      guard(() async {
        final rows = await _remote.auditLog(
          limit: limit,
          offset: offset,
          actorId: actorId,
          targetType: targetType,
          targetId: targetId,
          action: action,
        );
        final actors = await runRpc(() =>
            _profiles.profilesByIds(rows.map((r) => r['actor_id'] as String?)));
        return rows
            .map((r) => AuditEntryModel.fromJson(r,
                actor: actors[r['actor_id'] as String?]))
            .toList();
      });
}
