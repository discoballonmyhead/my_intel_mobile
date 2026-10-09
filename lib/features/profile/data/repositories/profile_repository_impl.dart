import '../../../../core/error/failure_mapper.dart';
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

  @override
  Future<Result<FollowStats>> getFollowStats(String targetUserId) {
    return guard(() async {
      final stats = await _remote.getFollowStats(targetUserId);
      return FollowStats(
        followers: stats.followers,
        following: stats.following,
        isFollowing: stats.isFollowing,
      );
    });
  }

  @override
  Future<Result<FollowStats>> toggleFollow(String targetUserId) {
    return guard(() async {
      final following = await _remote.isFollowing(targetUserId);
      if (following) {
        await _remote.unfollow(targetUserId);
      } else {
        await _remote.follow(targetUserId);
      }
      final stats = await _remote.getFollowStats(targetUserId);
      return FollowStats(
        followers: stats.followers,
        following: stats.following,
        isFollowing: stats.isFollowing,
      );
    });
  }

  @override
  Future<Result<List<String>>> getFollowedUserIds() =>
      guard(_remote.getFollowedUserIds);

  @override
  Future<Result<List<Profile>>> getFollowList(String userId,
          {required bool followers}) =>
      guard(() async => _remote.getFollowList(userId, followers: followers));

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
