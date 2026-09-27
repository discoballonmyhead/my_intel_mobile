import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../account/domain/entities/user_access.dart';
import '../entities/admin_entities.dart';
import '../repositories/admin_repository.dart';

Result<T>? _requireReason<T>(String? reason) =>
    (reason == null || reason.trim().isEmpty)
        ? Err<T>(const ValidationFailure('A reason is required.'))
        : null;

class GetAdminStats implements UseCase<AdminStats, NoParams> {
  const GetAdminStats(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<AdminStats>> call(NoParams params) => _repository.getStats();
}

class AdminUsersQuery {
  const AdminUsersQuery({
    this.search,
    this.role,
    this.banned,
    this.limit = 50,
    this.offset = 0,
  });
  final String? search;
  final AppRole? role;
  final bool? banned;
  final int limit;
  final int offset;
}

class GetAdminUsers implements UseCase<List<AdminUser>, AdminUsersQuery> {
  const GetAdminUsers(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<List<AdminUser>>> call(AdminUsersQuery q) {
    final search = q.search?.trim().replaceFirst(RegExp(r'^@'), '');
    return _repository.getUsers(
      search: search == null || search.isEmpty ? null : search,
      role: q.role,
      banned: q.banned,
      limit: q.limit,
      offset: q.offset,
    );
  }
}

class GetAdminUserDetail implements UseCase<AdminUserDetail, String> {
  const GetAdminUserDetail(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<AdminUserDetail>> call(String userId) =>
      _repository.getUserDetail(userId);
}

class OsintApplicationsQuery {
  const OsintApplicationsQuery({
    this.filter = OsintStatusFilter.pending,
    this.limit = 50,
    this.offset = 0,
  });
  final OsintStatusFilter filter;
  final int limit;
  final int offset;
}

class GetOsintApplications
    implements UseCase<List<OsintApplicationReview>, OsintApplicationsQuery> {
  const GetOsintApplications(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<List<OsintApplicationReview>>> call(OsintApplicationsQuery q) =>
      _repository.getOsintApplications(
          status: q.filter.value, limit: q.limit, offset: q.offset);
}

class ReviewOsintParams {
  const ReviewOsintParams({required this.applicationId, this.note});
  final int applicationId;
  final String? note;
}

class ApproveOsint implements UseCase<void, ReviewOsintParams> {
  const ApproveOsint(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(ReviewOsintParams p) {
    final note = p.note?.trim();
    return _repository.approveOsint(p.applicationId,
        note: note == null || note.isEmpty ? null : note);
  }
}

class DeclineOsint implements UseCase<void, ReviewOsintParams> {
  const DeclineOsint(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(ReviewOsintParams p) async =>
      _requireReason<void>(p.note) ??
      await _repository.declineOsint(p.applicationId, p.note!.trim());
}

class UserReasonParams {
  const UserReasonParams({required this.userId, this.reason});
  final String userId;
  final String? reason;
}

/// Downgrades an OSINT analyst back to a regular user.
class RevokeOsint implements UseCase<void, UserReasonParams> {
  const RevokeOsint(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(UserReasonParams p) async =>
      _requireReason<void>(p.reason) ??
      await _repository.revokeOsint(p.userId, p.reason!.trim());
}

class RoleParams {
  const RoleParams({required this.userId, required this.role, this.reason});
  final String userId;
  final AppRole role;
  final String? reason;
}

class GrantRole implements UseCase<void, RoleParams> {
  const GrantRole(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(RoleParams p) => _repository.grantRole(p.userId, p.role);
}

class RevokeRole implements UseCase<void, RoleParams> {
  const RevokeRole(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(RoleParams p) =>
      _repository.revokeRole(p.userId, p.role, reason: p.reason);
}

class BanUserParams {
  const BanUserParams({
    required this.userId,
    required this.reason,
    this.duration,
    this.hideContent = false,
    this.reportId,
  });
  final String userId;
  final String reason;

  /// Null = permanent ban; otherwise a suspension.
  final Duration? duration;
  final bool hideContent;
  final int? reportId;
}

class BanUser implements UseCase<int, BanUserParams> {
  const BanUser(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<int>> call(BanUserParams p) async {
    final missing = _requireReason<int>(p.reason);
    if (missing != null) return missing;
    if (p.duration != null && p.duration! <= Duration.zero) {
      return const Err(ValidationFailure('Pick a suspension length.'));
    }
    return _repository.banUser(
      p.userId,
      reason: p.reason.trim(),
      duration: p.duration,
      hideContent: p.hideContent,
      reportId: p.reportId,
    );
  }
}

class UnbanUser implements UseCase<void, UserReasonParams> {
  const UnbanUser(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(UserReasonParams p) =>
      _repository.unbanUser(p.userId, reason: p.reason);
}

class LiftSanctionParams {
  const LiftSanctionParams({required this.sanctionId, this.reason});
  final int sanctionId;
  final String? reason;
}

class LiftSanction implements UseCase<void, LiftSanctionParams> {
  const LiftSanction(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(LiftSanctionParams p) =>
      _repository.liftSanction(p.sanctionId, reason: p.reason);
}

/// Admin removal of someone else's account ("remove user").
class AdminDeleteAccount implements UseCase<void, UserReasonParams> {
  const AdminDeleteAccount(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<void>> call(UserReasonParams p) async =>
      _requireReason<void>(p.reason) ??
      await _repository.deleteAccount(p.userId, p.reason!.trim());
}

class AuditLogQuery {
  const AuditLogQuery({
    this.limit = 100,
    this.offset = 0,
    this.actorId,
    this.targetType,
    this.targetId,
    this.action,
  });
  final int limit;
  final int offset;
  final String? actorId;
  final String? targetType;
  final String? targetId;
  final String? action;
}

class GetAuditLog implements UseCase<List<AuditEntry>, AuditLogQuery> {
  const GetAuditLog(this._repository);
  final AdminRepository _repository;

  @override
  Future<Result<List<AuditEntry>>> call(AuditLogQuery q) => _repository.getAuditLog(
        limit: q.limit,
        offset: q.offset,
        actorId: q.actorId,
        targetType: q.targetType,
        targetId: q.targetId,
        action: q.action,
      );
}
