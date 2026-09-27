import 'package:equatable/equatable.dart';

/// Roles stored in `admin.user_roles`. A plain user holds none of them.
enum AppRole {
  osint('osint', 'OSINT ANALYST'),
  moderator('moderator', 'MODERATOR'),
  admin('admin', 'ADMIN'),
  superAdmin('super_admin', 'SUPER ADMIN');

  const AppRole(this.value, this.label);

  final String value;
  final String label;

  static AppRole? fromValue(String? value) {
    for (final role in AppRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }

  /// Mirrors `admin.role_rank()`.
  int get rank => switch (this) {
        AppRole.superAdmin => 3,
        AppRole.admin => 2,
        AppRole.moderator => 1,
        AppRole.osint => 0,
      };
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
    this.isOsint = false,
    this.isStaff = false,
    this.isAdmin = false,
    this.isBanned = false,
    this.activeSanctions = const [],
  });

  static const UserAccess none = UserAccess();

  final Set<AppRole> roles;
  final bool isOsint;
  final bool isStaff;
  final bool isAdmin;
  final bool isBanned;
  final List<Sanction> activeSanctions;

  bool get isSuperAdmin => roles.contains(AppRole.superAdmin);

  int get rank => roles.fold(0, (max, r) => r.rank > max ? r.rank : max);

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
  List<Object?> get props =>
      [roles, isOsint, isStaff, isAdmin, isBanned, activeSanctions];
}
