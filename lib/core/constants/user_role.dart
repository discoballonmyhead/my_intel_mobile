/// Roles stored in `identity.profiles.role`.
///
/// Shared by several features (auth, profile, feed, moderation), so it lives in
/// core rather than in any one feature's domain folder. The weights mirror
/// `moderation.set_note_weight()` on the database side.
enum UserRole {
  public('public', 'PUBLIC', 1),
  reporter('reporter', 'REPORTER', 1),
  osint('osint', 'OSINT ANALYST', 3),
  moderator('moderator', 'MODERATOR', 3),
  admin('admin', 'ADMIN', 10);

  const UserRole(this.value, this.label, this.noteWeight);

  final String value;
  final String label;

  /// Weight this role's community note carries toward the claim threshold.
  final int noteWeight;

  static UserRole fromValue(String? value) => switch (value) {
        'admin' => UserRole.admin,
        'osint' => UserRole.osint,
        'moderator' => UserRole.moderator,
        'reporter' => UserRole.reporter,
        _ => UserRole.public,
      };

  bool get canPublishStories => this == osint || this == admin;
  bool get isAdmin => this == admin;
  bool get isStaff => this == admin || this == moderator;
}
