import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../domain/entities/user_access.dart';

class SanctionModel extends Sanction {
  const SanctionModel({
    required super.id,
    required super.kind,
    required super.reason,
    required super.createdAt,
    super.userId,
    super.expiresAt,
    super.liftedAt,
    super.issuedBy,
    super.liftReason,
    super.reportId,
  });

  factory SanctionModel.fromJson(Map<String, dynamic> json) {
    return SanctionModel(
      id: asInt(json['id']) ?? 0,
      kind: SanctionKind.fromValue(json['kind'] as String?),
      reason: (json['reason'] as String?) ?? '',
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      userId: json['user_id'] as String?,
      expiresAt: parseTimestamp(json['expires_at']),
      liftedAt: parseTimestamp(json['lifted_at']),
      issuedBy: json['issued_by'] as String?,
      liftReason: json['lift_reason'] as String?,
      reportId: asInt(json['report_id']),
    );
  }
}

class UserAccessModel extends UserAccess {
  const UserAccessModel({
    super.roles,
    super.permissions,
    super.staffRole,
    super.rank,
    super.isOsint,
    super.isReporter,
    super.isStaff,
    super.isAdmin,
    super.isAppAdmin,
    super.isBanned,
    super.activeSanctions,
  });

  factory UserAccessModel.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>? ?? const [])
        .map((r) => AppRole.fromValue(r as String?))
        .whereType<AppRole>()
        .toSet();
    final sanctions = (json['active_sanctions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => SanctionModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final isStaff = (json['is_staff'] as bool?) ?? false;
    final isAdmin = (json['is_admin'] as bool?) ?? false;
    return UserAccessModel(
      roles: roles,
      // staff permission keys from the matrix (migration 15); empty for
      // everyone else
      permissions: (json['permissions'] as List<dynamic>? ?? const []).whereType<String>().toSet(),
      staffRole: AppRole.fromValue(json['staff_role'] as String?),
      rank: asInt(json['rank']),
      isOsint: (json['is_osint'] as bool?) ?? false,
      isReporter: (json['is_reporter'] as bool?) ?? false,
      isStaff: isStaff,
      isAdmin: isAdmin,
      isAppAdmin: (json['is_app_admin'] as bool?) ?? false,
      isBanned: (json['is_banned'] as bool?) ?? false,
      activeSanctions: sanctions,
    );
  }
}
