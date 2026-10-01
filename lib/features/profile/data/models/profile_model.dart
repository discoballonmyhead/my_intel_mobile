import '../../../../core/constants/user_role.dart';
import '../../../../core/utils/date_x.dart';
import '../../domain/entities/profile.dart';

class ProfileModel extends Profile {
  const ProfileModel({
    required super.id,
    required super.username,
    required super.role,
    super.email,
    super.score,
    super.auraPoints,
    super.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: (json['username'] as String?) ?? 'unknown',
      role: UserRole.fromValue(json['role'] as String?),
      email: json['email'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      auraPoints: (json['aura_points'] as num?)?.toInt() ?? 0,
      createdAt: parseTimestamp(json['created_at']),
    );
  }

  /// Only the columns the "Users can update own profile" policy allows.
  Map<String, dynamic> toUpdateJson() => {'username': username};

  /// The projection used everywhere a profile is attached to another row.
  static const String columns = 'id, username, role, score, aura_points, created_at';
}

class OsintApplicationModel extends OsintApplication {
  const OsintApplicationModel({
    required super.id,
    required super.channelName,
    required super.handle,
    super.userId,
    super.portfolio,
    super.why,
    super.status,
    super.createdAt,
    super.reviewedAt,
  });

  factory OsintApplicationModel.fromJson(Map<String, dynamic> json) {
    return OsintApplicationModel(
      id: (json['id'] as num).toInt(),
      channelName: (json['channel_name'] as String?) ?? '',
      handle: (json['handle'] as String?) ?? '',
      userId: json['user_id'] as String?,
      portfolio: json['portfolio'] as String?,
      why: json['why'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: parseTimestamp(json['created_at']),
      reviewedAt:
          parseTimestamp(json['reviewed_at'] ?? json['updated_at']),
    );
  }
}
