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
    this.followsYou = false,
  });

  final int followers;
  final int following;
  final bool isFollowing;

  /// The profile follows the viewer back ("Follows you" chip).
  final bool followsYou;

  FollowStats copyWith({
    int? followers,
    int? following,
    bool? isFollowing,
    bool? followsYou,
  }) {
    return FollowStats(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isFollowing: isFollowing ?? this.isFollowing,
      followsYou: followsYou ?? this.followsYou,
    );
  }

  @override
  List<Object?> get props => [followers, following, isFollowing, followsYou];
}

enum FollowListKind {
  followers('followers', 'FOLLOWERS'),
  following('following', 'FOLLOWING');

  const FollowListKind(this.value, this.label);
  final String value;
  final String label;

  static FollowListKind fromValue(String? value) =>
      value == 'following' ? FollowListKind.following : FollowListKind.followers;
}

/// One row of a followers / following list.
class FollowListEntry extends Equatable {
  const FollowListEntry({
    required this.profile,
    required this.isFollowing,
    this.followedAt,
  });

  final Profile profile;

  /// Whether the viewer follows this person.
  final bool isFollowing;
  final DateTime? followedAt;

  FollowListEntry copyWith({bool? isFollowing}) => FollowListEntry(
        profile: profile,
        isFollowing: isFollowing ?? this.isFollowing,
        followedAt: followedAt,
      );

  @override
  List<Object?> get props => [profile, isFollowing, followedAt];
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
  });

  final int id;
  final String channelName;
  final String handle;
  final String? userId;
  final String? portfolio;
  final String? why;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [id, channelName, handle, status];
}
