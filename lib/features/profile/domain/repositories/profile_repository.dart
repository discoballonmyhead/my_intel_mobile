import '../../../../core/utils/result.dart';
import '../entities/profile.dart';

abstract interface class ProfileRepository {
  Future<Result<Profile>> getProfile(String userId);

  Future<Result<Profile>> getProfileByUsername(String username);

  Future<Result<Profile>> updateProfile(
    String userId, {
    String? username,
  });

  Future<Result<FollowStats>> getFollowStats(String targetUserId);

  /// Follows if not following, unfollows otherwise. Returns the new state.
  Future<Result<FollowStats>> toggleFollow(String targetUserId);

  Future<Result<List<String>>> getFollowedUserIds();

  Future<Result<List<Profile>>> getFollowList(String userId,
      {required bool followers});

  Future<Result<List<Profile>>> searchProfiles(String query, {int limit = 10});

  Future<Result<void>> submitOsintApplication({
    required String channelName,
    required String handle,
    String? portfolio,
    String? why,
  });

  Future<Result<OsintApplication?>> getMyApplication();

  /// Admin only — RLS enforces the role check server-side.
  Future<Result<List<OsintApplication>>> getAllApplications();

  Future<Result<void>> setApplicationStatus(int applicationId, String status);

  Future<Result<void>> awardAuraPoints(String userId, int points);
}
