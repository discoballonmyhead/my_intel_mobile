import 'package:equatable/equatable.dart';

/// Roles stored in `admin.user_roles`. A plain user holds none of them.
///
/// Two kinds: badges (OSINT analyst, Reporter) that unlock publishing, and
/// staff roles (moderator → app admin), of which a person holds at most one.
/// What a staff role may do comes from the permission matrix on the server
/// (`admin.role_permissions`), not from this enum.
enum AppRole {
  appAdmin('app_admin', 'APP ADMIN'),
  superAdmin('super_admin', 'SUPER ADMIN'),
  admin('admin', 'ADMIN'),
  moderator('moderator', 'MODERATOR'),
  osint('osint', 'OSINT ANALYST'),
  reporter('reporter', 'REPORTER'),

  /// Holds a piece of the governance key (migration 23). Super admins and
  /// app admins only; named by an app admin.
  chatEncryptor('chat_encryptor', 'KEY HOLDER');

  const AppRole(this.value, this.label);

  final String value;
  final String label;

  static AppRole? fromValue(String? value) {
    for (final role in AppRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }

  /// Mirrors `admin.staff_roles.rank` (badges are 0).
  int get rank => switch (this) {
        AppRole.appAdmin => 4,
        AppRole.superAdmin => 3,
        AppRole.admin => 2,
        AppRole.moderator => 1,
        AppRole.osint || AppRole.reporter || AppRole.chatEncryptor => 0,
      };

  bool get isBadge => this == osint || this == reporter;
  bool get isStaff => rank > 0;

  /// Sentence-case name for people-facing text.
  String get displayName => switch (this) {
        AppRole.appAdmin => 'App admin',
        AppRole.superAdmin => 'Super admin',
        AppRole.admin => 'Admin',
        AppRole.moderator => 'Moderator',
        AppRole.osint => 'OSINT analyst',
        AppRole.reporter => 'Reporter',
        AppRole.chatEncryptor => 'Key holder',
      };

  static const List<AppRole> staffRoles = [moderator, admin, superAdmin, appAdmin];
  static const List<AppRole> badges = [reporter, osint];
}

enum SanctionKind {
  warning('warning', 'WARNING'),
  suspension('suspension', 'SUSPENSION'),
  ban('ban', 'BAN'),
  osintRevoked('osint_revoked', 'OSINT REVOKED');

  const SanctionKind(this.value, this.label);

  final String value;
  final String label;

  static SanctionKind fromValue(String? value) => switch (value) {
        'suspension' => SanctionKind.suspension,
        'ban' => SanctionKind.ban,
        'osint_revoked' => SanctionKind.osintRevoked,
        _ => SanctionKind.warning,
      };

  bool get restrictsAccount =>
      this == SanctionKind.suspension || this == SanctionKind.ban;
}

/// A row of `admin.sanctions`.
class Sanction extends Equatable {
  const Sanction({
    required this.id,
    required this.kind,
    required this.reason,
    required this.createdAt,
    this.userId,
    this.expiresAt,
    this.liftedAt,
    this.issuedBy,
    this.liftReason,
    this.reportId,
  });

  final int id;
  final SanctionKind kind;
  final String reason;
  final DateTime createdAt;
  final String? userId;
  final DateTime? expiresAt;
  final DateTime? liftedAt;
  final String? issuedBy;
  final String? liftReason;
  final int? reportId;

  bool get isPermanent => expiresAt == null;

  bool get isActive =>
      liftedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()));

  @override
  List<Object?> get props => [id, kind, reason, expiresAt, liftedAt];
}

/// What the signed-in user may do, from `auth_get_my_access()`.
class UserAccess extends Equatable {
  const UserAccess({
    this.roles = const {},
    this.permissions = const {},
    this.staffRole,
    int? rank,
    this.isOsint = false,
    this.isReporter = false,
    this.isStaff = false,
    this.isAdmin = false,
    this.isAppAdmin = false,
    this.isBanned = false,
    this.activeSanctions = const [],
  }) : _rank = rank;

  static const UserAccess none = UserAccess();

  final Set<AppRole> roles;

  /// Permission keys this person's staff role grants (the admin app's `Perm`).
  final Set<String> permissions;
  final AppRole? staffRole;
  final int? _rank;
  final bool isOsint;
  final bool isReporter;
  final bool isStaff;
  final bool isAdmin;
  final bool isAppAdmin;
  final bool isBanned;
  final List<Sanction> activeSanctions;

  int get rank => _rank ?? roles.fold(0, (max, r) => r.rank > max ? r.rank : max);

  bool get isSuperAdmin => isAppAdmin || rank >= 3;

  /// Holds a piece of the governance key.
  bool get isKeyHolder => roles.contains(AppRole.chatEncryptor) && rank >= 3;

  /// May publish news, articles and go live.
  bool get canReportNews => isReporter || isOsint || isStaff;

  /// UI hint only: every RPC checks the same permission again.
  bool can(String permission) => isAppAdmin || permissions.contains(permission);

  bool canAny(Iterable<String> keys) => keys.any(can);

  /// The ban or suspension currently locking the account, if any.
  Sanction? get activeRestriction {
    for (final s in activeSanctions) {
      if (s.kind.restrictsAccount) return s;
    }
    return null;
  }

  List<Sanction> get activeWarnings => activeSanctions
      .where((s) => s.kind == SanctionKind.warning)
      .toList(growable: false);

  @override
  List<Object?> get props => [
        roles,
        permissions,
        staffRole,
        rank,
        isOsint,
        isReporter,
        isStaff,
        isAdmin,
        isAppAdmin,
        isBanned,
        activeSanctions,
      ];
}
