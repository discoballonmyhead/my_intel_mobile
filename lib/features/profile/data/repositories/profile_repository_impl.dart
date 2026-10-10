import '../../../../core/error/failure_mapper.dart';
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<Profile>> getProfile(String userId) =>
      guard(() => _remote.getProfile(userId));

  @override
  Future<Result<Profile>> getProfileByUsername(String username) =>
      guard(() => _remote.getProfileByUsername(username));

  @override
  Future<Result<Profile>> updateProfile(String userId, {String? username}) =>
      guard(() => _remote.updateProfile(userId, username: username));

  FollowStats _toStats(Map<String, dynamic> raw) {
    final s = ProfileRemoteDataSourceImpl.parseStats(raw);
    return FollowStats(
      followers: s.followers,
      following: s.following,
      isFollowing: s.isFollowing,
      followsYou: s.followsYou,
    );
  }

  @override
  Future<Result<FollowStats>> getFollowStats(String targetUserId) {
    return guard(() async {
      final stats = await _remote.getFollowStats(targetUserId);
      return FollowStats(
        followers: stats.followers,
        following: stats.following,
        isFollowing: stats.isFollowing,
        followsYou: stats.followsYou,
      );
    });
  }

  /// One atomic server call (`follow_toggle`) instead of read-then-write.
  @override
  Future<Result<FollowStats>> toggleFollow(String targetUserId) => guard(
      () async => _toStats(await _remote.toggleFollowing(targetUserId)));

  @override
  Future<Result<FollowStats>> setFollowing(String targetUserId, bool follow) =>
      guard(() async =>
          _toStats(await _remote.setFollowing(targetUserId, follow)));

  @override
  Future<Result<List<FollowListEntry>>> getFollowList(
    String profileId,
    FollowListKind kind, {
    int limit = 50,
    int offset = 0,
  }) {
    return guard(() async {
      final rows = await _remote.followList(profileId,
          kind: kind.value, limit: limit, offset: offset);
      final profiles = await runRpc(
          () => _remote.profilesByIds(rows.map((r) => r['user_id'] as String?)));
      return [
        for (final row in rows)
          if (profiles[row['user_id'] as String?] case final profile?)
            FollowListEntry(
              profile: profile,
              isFollowing: row['is_following'] as bool? ?? false,
              followedAt: parseTimestamp(row['followed_at']),
            ),
      ];
    });
  }

  @override
  Future<Result<List<String>>> getFollowedUserIds() =>
      guard(_remote.getFollowedUserIds);

  @override
  Future<Result<List<Profile>>> searchProfiles(String query, {int limit = 10}) =>
      guard(() async => _remote.searchProfiles(query, limit: limit));

  @override
  Future<Result<void>> submitOsintApplication({
    required String channelName,
    required String handle,
    String? portfolio,
    String? why,
  }) {
    return guard(() => _remote.submitOsintApplication({
          'channel_name': channelName,
          'handle': handle,
          'portfolio': portfolio,
          'why': why,
        }));
  }

  @override
  Future<Result<OsintApplication?>> getMyApplication() =>
      guard(_remote.getMyApplication);

  @override
  Future<Result<List<OsintApplication>>> getAllApplications() =>
      guard(() async => _remote.getAllApplications());

  @override
  Future<Result<void>> setApplicationStatus(int applicationId, String status) =>
      guard(() => _remote.setApplicationStatus(applicationId, status));

  @override
  Future<Result<void>> awardAuraPoints(String userId, int points) =>
      guard(() => _remote.awardAuraPoints(userId, points));
}
