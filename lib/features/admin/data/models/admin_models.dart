import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../../account/data/models/user_access_model.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../../moderation/data/models/report_model.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/admin_entities.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

Set<AppRole> _roles(Object? v) => (v is List ? v : const [])
    .map((r) => AppRole.fromValue(r is Map ? r['role'] as String? : r as String?))
    .whereType<AppRole>()
    .toSet();

ProfileModel? _profile(Object? v) {
  final m = _map(v);
  return m == null || m['id'] == null ? null : ProfileModel.fromJson(m);
}

class AdminStatsModel extends AdminStats {
  const AdminStatsModel({
    super.usersTotal,
    super.usersNew7d,
    super.openReports,
    super.openReportTargets,
    super.pendingOsint,
    super.osintUsers,
    super.activeBans,
    super.posts24h,
    super.postsUnderReview,
    super.messages24h,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> j) => AdminStatsModel(
        usersTotal: asInt(j['users_total']) ?? 0,
        usersNew7d: asInt(j['users_new_7d']) ?? 0,
        openReports: asInt(j['open_reports']) ?? 0,
        openReportTargets: asInt(j['open_report_targets']) ?? 0,
        pendingOsint: asInt(j['pending_osint']) ?? 0,
        osintUsers: asInt(j['osint_users']) ?? 0,
        activeBans: asInt(j['active_bans']) ?? 0,
        posts24h: asInt(j['posts_24h']) ?? 0,
        postsUnderReview: asInt(j['posts_under_review']) ?? 0,
        messages24h: asInt(j['messages_24h']) ?? 0,
      );
}

class AdminUserModel extends AdminUser {
  const AdminUserModel({
    required super.userId,
    super.email,
    super.createdAt,
    super.lastSignInAt,
    super.profile,
    super.roles,
    super.isBanned,
    super.bannedUntil,
    super.openReportsAgainst,
    super.latestOsintStatus,
  });

  /// Row of `admin_get_users()`.
  factory AdminUserModel.fromJson(Map<String, dynamic> j) => AdminUserModel(
        userId: j['user_id'] as String,
        email: j['email'] as String?,
        createdAt: parseTimestamp(j['created_at']),
        lastSignInAt: parseTimestamp(j['last_sign_in_at']),
        profile: _profile(j['profile']),
        roles: _roles(j['roles']),
        isBanned: (j['is_banned'] as bool?) ?? false,
        // 'infinity' (permanent) doesn't parse → null.
        bannedUntil: parseTimestamp(j['banned_until']),
        openReportsAgainst: asInt(j['open_reports_against']) ?? 0,
        latestOsintStatus: j['latest_osint_status'] as String?,
      );
}

class AuditEntryModel extends AuditEntry {
  const AuditEntryModel({
    required super.id,
    required super.action,
    required super.targetType,
    required super.targetId,
    required super.createdAt,
    super.actorId,
    super.actor,
    super.reason,
    super.metadata,
  });

  factory AuditEntryModel.fromJson(Map<String, dynamic> j, {Profile? actor}) =>
      AuditEntryModel(
        id: asInt(j['id']) ?? 0,
        action: (j['action'] as String?) ?? '',
        targetType: (j['target_type'] as String?) ?? '',
        targetId: '${j['target_id']}',
        createdAt: parseTimestamp(j['created_at']) ?? DateTime.now().toUtc(),
        actorId: j['actor_id'] as String?,
        actor: actor,
        reason: j['reason'] as String?,
        metadata: _map(j['metadata']) ?? const {},
      );
}

class AdminUserDetailModel extends AdminUserDetail {
  const AdminUserDetailModel({
    required super.user,
    super.sanctions,
    super.reportsAgainst,
    super.reportsFiled,
    super.osintApplications,
    super.audit,
  });

  /// `admin_get_user_detail()` jsonb. [actors] resolves audit actor ids.
  factory AdminUserDetailModel.fromJson(
    Map<String, dynamic> j, {
    Map<String, Profile> actors = const {},
  }) {
    final user = _map(j['user']) ?? const {};
    final sanctions = _list(j['sanctions']).map(SanctionModel.fromJson).toList();
    final isBanned = (j['is_banned'] as bool?) ?? false;
    DateTime? bannedUntil;
    for (final s in sanctions) {
      if (s.isActive && s.kind.restrictsAccount && s.expiresAt != null) {
        bannedUntil = s.expiresAt;
      }
    }

    return AdminUserDetailModel(
      user: AdminUserModel(
        userId: (user['id'] as String?) ?? '',
        email: user['email'] as String?,
        createdAt: parseTimestamp(user['created_at']),
        lastSignInAt: parseTimestamp(user['last_sign_in_at']),
        profile: _profile(j['profile']),
        roles: _roles(j['roles']),
        isBanned: isBanned,
        bannedUntil: bannedUntil,
      ),
      sanctions: sanctions,
      reportsAgainst:
          _list(j['reports_against']).map(ReportModel.fromJson).toList(),
      reportsFiled: asInt(j['reports_filed']) ?? 0,
      osintApplications: _list(j['osint_applications'])
          .map(OsintApplicationModel.fromJson)
          .toList(),
      audit: _list(j['audit'])
          .map((a) => AuditEntryModel.fromJson(a,
              actor: actors[a['actor_id'] as String?]))
          .toList(),
    );
  }

  static Iterable<String?> auditActorIds(Map<String, dynamic> j) =>
      _list(j['audit']).map((a) => a['actor_id'] as String?);
}

class OsintApplicationReviewModel extends OsintApplicationReview {
  const OsintApplicationReviewModel({
    required super.application,
    super.profile,
    super.email,
    super.isOsint,
  });

  factory OsintApplicationReviewModel.fromJson(Map<String, dynamic> j) =>
      OsintApplicationReviewModel(
        application: OsintApplicationModel.fromJson(_map(j['application']) ?? const {'id': 0}),
        profile: _profile(j['profile']),
        email: j['email'] as String?,
        isOsint: (j['is_osint'] as bool?) ?? false,
      );
}
