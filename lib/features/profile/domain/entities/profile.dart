import 'package:equatable/equatable.dart';

import '../../../../core/constants/user_role.dart';

/// A row of `identity.profiles`.
class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.username,
    required this.role,
    this.email,
    this.score = 0,
    this.auraPoints = 0,
    this.createdAt,
  });

  final String id;
  final String username;
  final UserRole role;
  final String? email;

  /// Credibility, maintained by `moderation.calculate_credibility()`.
  /// Ranges -50..100 and is only computed for analysts.
  final int score;

  /// Community karma, bumped through the `upsert_aura_points` RPC.
  final int auraPoints;

  final DateTime? createdAt;

  bool get isAnalyst => role.canPublishStories;

  /// Buckets used for the credibility chip on cards and headers.
  CredibilityBand get band {
    if (!isAnalyst) return CredibilityBand.unrated;
    if (score >= 75) return CredibilityBand.high;
    if (score >= 50) return CredibilityBand.moderate;
    if (score >= 25) return CredibilityBand.low;
    return CredibilityBand.poor;
  }

  Profile copyWith({String? username, int? score, int? auraPoints, UserRole? role}) {
    return Profile(
      id: id,
      username: username ?? this.username,
      role: role ?? this.role,
      email: email,
      score: score ?? this.score,
      auraPoints: auraPoints ?? this.auraPoints,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, username, role, score, auraPoints];
}

enum CredibilityBand { high, moderate, low, poor, unrated }

/// Follower / following counts plus whether the viewer follows this profile.
class FollowStats extends Equatable {
  const FollowStats({
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
  });

  final int followers;
  final int following;
  final bool isFollowing;

  FollowStats copyWith({int? followers, int? following, bool? isFollowing}) {
    return FollowStats(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [followers, following, isFollowing];
}

/// A row of `identity.osint_applications`.
class OsintApplication extends Equatable {
  const OsintApplication({
    required this.id,
    required this.channelName,
    required this.handle,
    this.userId,
    this.portfolio,
    this.why,
    this.status = 'pending',
    this.createdAt,
    this.reviewedAt,
  });

  /// How long after a rejection before the user may apply again.
  static const Duration reapplyCooldown = Duration(days: 30);

  final int id;
  final String channelName;
  final String handle;
  final String? userId;
  final String? portfolio;
  final String? why;
  final String status;
  final DateTime? createdAt;

  /// When staff decided on it. Null if the backend doesn't send it.
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  /// For a rejected application: when a new one may be sent. Counted from the
  /// review date, or from submission when the review date is unknown.
  DateTime? get reapplyAvailableAt {
    if (!isRejected) return null;
    final from = reviewedAt ?? createdAt;
    return from?.add(reapplyCooldown);
  }

  bool canReapply({DateTime? now}) {
    final at = reapplyAvailableAt;
    return at == null || !(now ?? DateTime.now().toUtc()).isBefore(at);
  }

  @override
  List<Object?> get props => [id, channelName, handle, status, reviewedAt];
}
