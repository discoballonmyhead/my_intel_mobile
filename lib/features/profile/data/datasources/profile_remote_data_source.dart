import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../models/profile_model.dart';
import 'dart:developer' as dev;

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> getProfileByUsername(String username);
  Future<ProfileModel> updateProfile(String userId, {String? username});
  Future<({int followers, int following, bool isFollowing})> getFollowStats(
      String targetUserId);
  Future<bool> isFollowing(String targetUserId);
  Future<void> follow(String targetUserId);
  Future<void> unfollow(String targetUserId);
  Future<List<String>> getFollowedUserIds();
  Future<List<ProfileModel>> searchProfiles(String query, {int limit});
  Future<void> submitOsintApplication(Map<String, dynamic> payload);
  Future<OsintApplicationModel?> getMyApplication();
  Future<List<OsintApplicationModel>> getAllApplications();
  Future<void> setApplicationStatus(int applicationId, String status);
  Future<void> awardAuraPoints(String userId, int points);
  Future<Map<String, ProfileModel>> profilesByIds(Iterable<String?> ids);
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

  @override
  Future<({int followers, int following, bool isFollowing})> getFollowStats(
      String targetUserId) async {
    dev.log('getFollowStats called for targetUserId: $targetUserId',
        name: _logName);
    try {
      final res = await _service
          .rpc('profile_get_stats', params: {'p_profile_id': targetUserId});
      final map = res as List<dynamic>;
      final data = map.first as Map<String, dynamic>;
      dev.log('getFollowStats success: ${data.toString()}', name: _logName);
      return (
        followers: data['followers'] as int? ?? 0,
        following: data['following'] as int? ?? 0,
        isFollowing: data['is_following'] as bool? ?? false,
      );
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in getFollowStats', error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<bool> isFollowing(String targetUserId) async {
    dev.log('isFollowing called for targetUserId: $targetUserId',
        name: _logName);
    try {
      final res = await _service.rpc('social_is_following',
          params: {'p_target_user_id': targetUserId});
      dev.log('isFollowing result: $res', name: _logName);
      return res as bool? ?? false;
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in isFollowing', error: e, name: _logName);
      rethrow;
    }
  }

  @override
  Future<void> follow(String targetUserId) async {
    dev.log('follow called for targetUserId: $targetUserId', name: _logName);
    try {
      await _service.rpc('social_toggle_follow',
          params: {'p_target_user_id': targetUserId});
      dev.log('follow toggle executed successfully', name: _logName);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in follow', error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> unfollow(String targetUserId) async {
    dev.log('unfollow called for targetUserId: $targetUserId', name: _logName);
    try {
      await _service.rpc('social_toggle_follow',
          params: {'p_target_user_id': targetUserId});
      dev.log('unfollow toggle executed successfully', name: _logName);
    } on PostgrestException catch (e) {
      dev.log('PostgrestException in unfollow', error: e, name: _logName);
      throw ex.ServerException(e.message, code: e.code);
    }
  }

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
}
