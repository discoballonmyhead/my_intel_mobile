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
    super.isOsint,
    super.isStaff,
    super.isAdmin,
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
    return UserAccessModel(
      roles: roles,
      isOsint: (json['is_osint'] as bool?) ?? false,
      isStaff: (json['is_staff'] as bool?) ?? false,
      isAdmin: (json['is_admin'] as bool?) ?? false,
      isBanned: (json['is_banned'] as bool?) ?? false,
      activeSanctions: sanctions,
    );
  }
}
