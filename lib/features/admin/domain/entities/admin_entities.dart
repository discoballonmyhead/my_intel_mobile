import 'package:equatable/equatable.dart';

import '../../../account/domain/entities/user_access.dart';
import '../../../moderation/domain/entities/report.dart';
import '../../../profile/domain/entities/profile.dart';

/// `admin_get_stats()`.
class AdminStats extends Equatable {
  const AdminStats({
    this.usersTotal = 0,
    this.usersNew7d = 0,
    this.openReports = 0,
    this.openReportTargets = 0,
    this.pendingOsint = 0,
    this.osintUsers = 0,
    this.activeBans = 0,
    this.posts24h = 0,
    this.postsUnderReview = 0,
    this.messages24h = 0,
  });

  final int usersTotal;
  final int usersNew7d;
  final int openReports;
  final int openReportTargets;
  final int pendingOsint;
  final int osintUsers;
  final int activeBans;
  final int posts24h;
  final int postsUnderReview;
  final int messages24h;

  @override
  List<Object?> get props => [
        usersTotal,
        usersNew7d,
        openReports,
        openReportTargets,
        pendingOsint,
        osintUsers,
        activeBans,
        posts24h,
        postsUnderReview,
        messages24h,
      ];
}

/// One row of `admin_get_users()`. [email] is null for moderators.
class AdminUser extends Equatable {
  const AdminUser({
    required this.userId,
    this.email,
    this.createdAt,
    this.lastSignInAt,
    this.profile,
    this.roles = const {},
    this.isBanned = false,
    this.bannedUntil,
    this.openReportsAgainst = 0,
    this.latestOsintStatus,
  });

  final String userId;
  final String? email;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final Profile? profile;
  final Set<AppRole> roles;
  final bool isBanned;

  /// Null while banned means permanent.
  final DateTime? bannedUntil;
  final int openReportsAgainst;
  final String? latestOsintStatus;

  String get displayName =>
      profile?.username ??
      email ??
      (userId.length > 8 ? userId.substring(0, 8) : userId);

  int get rank => roles.fold(0, (max, r) => r.rank > max ? r.rank : max);

  @override
  List<Object?> get props =>
      [userId, profile, roles, isBanned, bannedUntil, openReportsAgainst];
}

/// Everything the admin console shows about one user.
class AdminUserDetail extends Equatable {
  const AdminUserDetail({
    required this.user,
    this.sanctions = const [],
    this.reportsAgainst = const [],
    this.reportsFiled = 0,
    this.osintApplications = const [],
    this.audit = const [],
  });

  final AdminUser user;
  final List<Sanction> sanctions;
  final List<Report> reportsAgainst;
  final int reportsFiled;
  final List<OsintApplication> osintApplications;

  /// Empty for moderators (admins only).
  final List<AuditEntry> audit;

  List<Sanction> get activeSanctions =>
      sanctions.where((s) => s.isActive).toList(growable: false);

  bool hasRole(AppRole role) => user.roles.contains(role);

  @override
  List<Object?> get props =>
      [user, sanctions, reportsAgainst, reportsFiled, osintApplications, audit];
}

/// A row of `admin.audit_log`.
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    this.actorId,
    this.actor,
    this.reason,
    this.metadata = const {},
  });

  final int id;
  final String action;
  final String targetType;
  final String targetId;
  final DateTime createdAt;
  final String? actorId;
  final Profile? actor;
  final String? reason;
  final Map<String, dynamic> metadata;

  String get actionLabel => action.replaceAll('_', ' ').toUpperCase();

  @override
  List<Object?> get props => [id, actor];
}

/// An OSINT application with the applicant attached.
class OsintApplicationReview extends Equatable {
  const OsintApplicationReview({
    required this.application,
    this.profile,
    this.email,
    this.isOsint = false,
  });

  final OsintApplication application;
  final Profile? profile;
  final String? email;
  final bool isOsint;

  @override
  List<Object?> get props => [application, profile, isOsint];
}

/// Filters for the OSINT review list.
enum OsintStatusFilter {
  pending('pending', 'PENDING'),
  approved('approved', 'APPROVED'),
  rejected('rejected', 'DECLINED'),
  all(null, 'ALL');

  const OsintStatusFilter(this.value, this.label);
  final String? value;
  final String label;
}
