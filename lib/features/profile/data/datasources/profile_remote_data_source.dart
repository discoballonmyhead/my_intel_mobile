import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/profile_model.dart';
import 'dart:developer' as dev;

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> getProfileByUsername(String username);
  Future<ProfileModel> updateProfile(String userId, {String? username});
  Future<({int followers, int following, bool isFollowing, bool followsYou})>
      getFollowStats(String targetUserId);
  Future<bool> isFollowing(String targetUserId);
  Future<void> follow(String targetUserId);
  Future<void> unfollow(String targetUserId);

  /// Follow (true) or unfollow (false); returns the target's fresh stats.
  Future<Map<String, dynamic>> setFollowing(String targetUserId, bool follow);

  /// Atomic server-side toggle; returns the target's fresh stats.
  Future<Map<String, dynamic>> toggleFollowing(String targetUserId);

  /// Raw rows of `follow_get_list` (user_id, followed_at, is_following).
  Future<List<Map<String, dynamic>>> followList(String profileId,
      {required String kind, int limit, int offset});
  Future<List<String>> getFollowedUserIds();
  Future<List<ProfileModel>> searchProfiles(String query, {int limit});
  Future<void> submitOsintApplication(Map<String, dynamic> payload);
  Future<OsintApplicationModel?> getMyApplication();
  Future<List<OsintApplicationModel>> getAllApplications();
  Future<void> setApplicationStatus(int applicationId, String status);
  Future<void> awardAuraPoints(String userId, int points);
  Future<Map<String, ProfileModel>> profilesByIds(Iterable<String?> ids);

  /// People who follow [userId] (followers) or whom [userId] follows,
  /// newest first.
  Future<List<ProfileModel>> getFollowList(String userId,
      {required bool followers});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  static const _logName = 'ProfileRemoteDataSource';

  @override
  Future<ProfileModel> getProfile(String userId) async {
    dev.log('getProfile called with userId: $userId', name: _logName);
    try {
      final response = await _service
          .rpc('profile_get_by_id', params: {'p_user_id': userId});
      final rows = response as List<dynamic>? ?? [];

      if (rows.isEmpty) {
        dev.log('Profile not found for userId: $userId', name: _logName);
        throw const ex.NotFoundException('Profile not found.');
      }

      dev.log('getProfile success for userId: $userId', name: _logName);
      return ProfileModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getProfile', error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<ProfileModel> getProfileByUsername(String username) async {
    dev.log('getProfileByUsername called with username: $username',
        name: _logName);
    try {
      final response = await _service
          .rpc('profile_get_by_username', params: {'p_username': username});
      final rows = response as List<dynamic>? ?? [];

      if (rows.isEmpty) {
        dev.log('Profile not found for username: $username', name: _logName);
        throw const ex.NotFoundException('No such channel.');
      }

      dev.log('getProfileByUsername success for username: $username',
          name: _logName);
      return ProfileModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getProfileByUsername',
          error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<ProfileModel> updateProfile(String userId, {String? username}) async {
    dev.log('updateProfile called for userId: $userId, username: $username',
        name: _logName);
    try {
      final response = await _service.rpc('profile_update', params: {
        'p_user_id': userId,
        'p_username': username,
      });
      final rows = response as List<dynamic>? ?? [];

      if (rows.isEmpty) {
        throw const ex.ServerException('Failed to update profile.');
      }

      dev.log('updateProfile success for userId: $userId', name: _logName);
      return ProfileModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in updateProfile', error: e, name: _logName);
      if (e.code == '23505') {
        throw const ex.ServerException('That username is already taken.');
      }
      if (e.code == '42501') {
        throw const ex.PermissionException(
            'You can only edit your own profile.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<OsintApplicationModel?> getMyApplication() async {
    dev.log('getMyApplication called', name: _logName);
    try {
      final response = await _service.rpc('auth_get_my_osint_application');
      final rows = response as List<dynamic>? ?? [];

      if (rows.isEmpty) {
        dev.log('getMyApplication returned null', name: _logName);
        return null;
      }

      dev.log('getMyApplication success', name: _logName);
      return OsintApplicationModel.fromJson(rows.first as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getMyApplication',
          error: e, name: _logName);
      rethrow;
    }
  }

  static ({int followers, int following, bool isFollowing, bool followsYou})
      _stats(Map<String, dynamic> data) => (
            followers: asInt(data['followers']) ?? 0,
            following: asInt(data['following']) ?? 0,
            isFollowing: data['is_following'] as bool? ?? false,
            followsYou: data['follows_you'] as bool? ?? false,
          );

  /// Exposed for the repository, which maps raw stats into [FollowStats].
  static ({int followers, int following, bool isFollowing, bool followsYou})
      parseStats(Map<String, dynamic> data) => _stats(data);

  @override
  Future<({int followers, int following, bool isFollowing, bool followsYou})>
      getFollowStats(String targetUserId) => runRpc(() async {
            final res = await _service.rpc<dynamic>(FollowRpc.stats,
                params: {'p_profile_id': targetUserId});
            return _stats(asRow(res) ?? const {});
          });

  @override
  Future<bool> isFollowing(String targetUserId) async =>
      (await getFollowStats(targetUserId)).isFollowing;

  @override
  Future<void> follow(String targetUserId) => setFollowing(targetUserId, true);

  @override
  Future<void> unfollow(String targetUserId) =>
      setFollowing(targetUserId, false);

  @override
  Future<Map<String, dynamic>> setFollowing(String targetUserId, bool follow) =>
      runRpc(() async {
        dev.log('setFollowing $targetUserId -> $follow', name: _logName);
        final res = await _service.rpc<dynamic>(FollowRpc.set, params: {
          'p_target_user_id': targetUserId,
          'p_follow': follow,
        });
        return asRow(res) ?? const {};
      });

  @override
  Future<Map<String, dynamic>> toggleFollowing(String targetUserId) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(FollowRpc.toggle,
            params: {'p_target_user_id': targetUserId});
        return asRow(res) ?? const {};
      });

  @override
  Future<List<Map<String, dynamic>>> followList(String profileId,
          {required String kind, int limit = 50, int offset = 0}) =>
      runRpc(() async => asRows(await _service.rpc<dynamic>(FollowRpc.list,
              params: {
                'p_profile_id': profileId,
                'p_kind': kind,
                'p_limit': limit,
                'p_offset': offset,
              })));

  @override
  Future<List<String>> getFollowedUserIds() async {
    dev.log('getFollowedUserIds called', name: _logName);
    try {
      final res =
          await _service.rpc<List<dynamic>>('social_get_followed_user_ids');
      final ids = res?.map((e) => e as String).toList() ?? [];
      dev.log('getFollowedUserIds returned ${ids.length} ids', name: _logName);
      return ids;
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getFollowedUserIds',
          error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<List<ProfileModel>> searchProfiles(String query,
      {int limit = 10}) async {
    dev.log('searchProfiles called with query: "$query", limit: $limit',
        name: _logName);
    try {
      final rows =
          await _service.rpc<List<dynamic>>('search_profiles_query', params: {
        'p_query': query,
        'p_limit': limit,
      });
      final profiles = List<Map<String, dynamic>>.from(rows ?? [])
          .map(ProfileModel.fromJson)
          .toList();
      dev.log('searchProfiles returned ${profiles.length} results',
          name: _logName);
      return profiles;
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in searchProfiles', error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<void> submitOsintApplication(Map<String, dynamic> payload) async {
    dev.log(
        'submitOsintApplication called with payload keys: ${payload.keys.join(',')}',
        name: _logName);
    try {
      await _service.rpc('auth_apply_osint', params: {
        'p_channel_name': payload['channel_name'],
        'p_handle': payload['handle'],
        'p_portfolio': payload['portfolio'],
        'p_why': payload['why'],
      });
      dev.log('submitOsintApplication success', name: _logName);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in submitOsintApplication',
          error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<OsintApplicationModel>> getAllApplications() async {
    dev.log('getAllApplications called', name: _logName);
    try {
      final rows =
          await _service.rpc<List<dynamic>>('auth_get_all_osint_applications');
      final apps = List<Map<String, dynamic>>.from(rows ?? [])
          .map(OsintApplicationModel.fromJson)
          .toList();
      dev.log('getAllApplications returned ${apps.length} applications',
          name: _logName);
      return apps;
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getAllApplications',
          error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<void> setApplicationStatus(int applicationId, String status) async {
    dev.log(
        'setApplicationStatus called for id: $applicationId to status: $status',
        name: _logName);
    try {
      await _service.rpc('auth_update_osint_application_status', params: {
        'p_app_id': applicationId,
        'p_status': status,
      });
      dev.log('setApplicationStatus success', name: _logName);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in setApplicationStatus',
          error: e, name: _logName);
      if (e.code == '42501') {
        throw const ex.PermissionException(
            'Only admins can review applications.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> awardAuraPoints(String userId, int points) async {
    dev.log('awardAuraPoints called for userId: $userId, points: $points',
        name: _logName);
    try {
      await _service.rpc<void>('gamification_upsert_aura',
          params: {'p_user_id': userId, 'p_points': points});
      dev.log('awardAuraPoints success', name: _logName);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in awardAuraPoints',
          error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<Map<String, ProfileModel>> profilesByIds(Iterable<String?> ids) async {
    final unique = ids.whereType<String>().toSet().toList();
    dev.log('profilesByIds called for ${unique.length} unique ids',
        name: _logName);

    if (unique.isEmpty) return const {};

    try {
      final rows = await _service
          .rpc<List<dynamic>>('profile_get_by_ids', params: {'p_ids': unique});

      final result = {
        for (final row in List<Map<String, dynamic>>.from(rows ?? []))
          row['id'] as String: ProfileModel.fromJson(row),
      };

      dev.log('profilesByIds success, returned ${result.length} profiles',
          name: _logName);
      return result;
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in profilesByIds', error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<List<ProfileModel>> getFollowList(String userId,
      {required bool followers}) async {
    // Same identity.follows table the web app reads; names come from
    // profile_get_by_ids since PostgREST can't embed across schemas.
    final mine = followers ? 'following_id' : 'follower_id';
    final theirs = followers ? 'follower_id' : 'following_id';
    try {
      final rows = await _service.identity
          .from('follows')
          .select(theirs)
          .eq(mine, userId)
          .order('id', ascending: false)
          .limit(500);
      final ids = [for (final r in rows) r[theirs] as String];
      final byId = await profilesByIds(ids);
      return [for (final id in ids) if (byId[id] case final p?) p];
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getFollowList', error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }
}
