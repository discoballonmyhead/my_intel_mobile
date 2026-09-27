import '../../../../core/utils/result.dart';
import '../../../account/domain/entities/user_access.dart';
import '../entities/admin_entities.dart';

abstract interface class AdminRepository {
  Future<Result<AdminStats>> getStats();

  Future<Result<List<AdminUser>>> getUsers({
    String? search,
    AppRole? role,
    bool? banned,
    int limit = 50,
    int offset = 0,
  });
  Future<Result<AdminUserDetail>> getUserDetail(String userId);

  Future<Result<List<OsintApplicationReview>>> getOsintApplications({
    String? status,
    int limit = 50,
    int offset = 0,
  });
  Future<Result<void>> approveOsint(int applicationId, {String? note});
  Future<Result<void>> declineOsint(int applicationId, String reason);
  Future<Result<void>> revokeOsint(String userId, String reason);

  Future<Result<void>> grantRole(String userId, AppRole role);
  Future<Result<void>> revokeRole(String userId, AppRole role, {String? reason});

  /// [duration] null = permanent ban. Returns the sanction id.
  Future<Result<int>> banUser(
    String userId, {
    required String reason,
    Duration? duration,
    bool hideContent = false,
    int? reportId,
  });
  Future<Result<void>> unbanUser(String userId, {String? reason});
  Future<Result<void>> liftSanction(int sanctionId, {String? reason});
  Future<Result<void>> deleteAccount(String userId, String reason);

  Future<Result<List<AuditEntry>>> getAuditLog({
    int limit = 100,
    int offset = 0,
    String? actorId,
    String? targetType,
    String? targetId,
    String? action,
  });
}
