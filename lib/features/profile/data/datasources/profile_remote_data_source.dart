import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../models/profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> getProfileByUsername(String username);
  Future<ProfileModel> updateProfile(String userId, {String? username});

  Future<({int followers, int following, bool isFollowing})> getFollowStats(
    String targetUserId,
  );
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

  /// Shared helper: resolve a batch of author ids into profiles.
  /// `content.posts.author_id` points at `identity.profiles`, and PostgREST
  /// cannot embed across schemas, so every feature that shows an author calls
  /// through here and merges the result client-side.
  Future<Map<String, ProfileModel>> profilesByIds(Iterable<String?> ids);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  String get _requireUserId {
    final id = _service.currentUserId;
    if (id == null) throw const ex.AuthException('You must be signed in.');
    return id;
  }

  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final row = await _service.identity
          .from(DbTables.profiles)
          .select(ProfileModel.columns)
          .eq('id', userId)
          .maybeSingle();
      if (row == null) throw const ex.NotFoundException('Profile not found.');
      return ProfileModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<ProfileModel> getProfileByUsername(String username) async {
    try {
      final row = await _service.identity
          .from(DbTables.profiles)
          .select(ProfileModel.columns)
          .eq('username', username)
          .maybeSingle();
      if (row == null) throw const ex.NotFoundException('No such channel.');
      return ProfileModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<ProfileModel> updateProfile(String userId, {String? username}) async {
    try {
      final payload = <String, dynamic>{
        if (username != null) 'username': username,
      };
      final row = await _service.identity
          .from(DbTables.profiles)
          .update(payload)
          .eq('id', userId)
          .select(ProfileModel.columns)
          .single();
      return ProfileModel.fromJson(row);
    } on PostgrestException catch (e) {
      // 23505 is a unique-violation: the username is taken.
      if (e.code == '23505') {
        throw const ex.ServerException('That username is already taken.');
      }
      if (e.code == '42501') {
        throw const ex.PermissionException('You can only edit your own profile.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<({int followers, int following, bool isFollowing})> getFollowStats(
    String targetUserId,
  ) async {
    try {
      final followersFuture = _service.identity
          .from(DbTables.follows)
          .select('id')
          .eq('following_id', targetUserId)
          .count(CountOption.exact);

      final followingFuture = _service.identity
          .from(DbTables.follows)
          .select('id')
          .eq('follower_id', targetUserId)
          .count(CountOption.exact);

      final results = await Future.wait([followersFuture, followingFuture]);
      final following = await isFollowing(targetUserId);

      return (
        followers: results[0].count,
        following: results[1].count,
        isFollowing: following,
      );
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<bool> isFollowing(String targetUserId) async {
    final me = _service.currentUserId;
    if (me == null) return false;
    final row = await _service.identity
        .from(DbTables.follows)
        .select('id')
        .eq('follower_id', me)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> follow(String targetUserId) async {
    try {
      await _service.identity.from(DbTables.follows).insert({
        'follower_id': _requireUserId,
        'following_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> unfollow(String targetUserId) async {
    try {
      await _service.identity
          .from(DbTables.follows)
          .delete()
          .eq('follower_id', _requireUserId)
          .eq('following_id', targetUserId);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<String>> getFollowedUserIds() async {
    final me = _service.currentUserId;
    if (me == null) return const [];
    final rows = await _service.identity
        .from(DbTables.follows)
        .select('following_id')
        .eq('follower_id', me);
    return rows
        .map((r) => r['following_id'] as String?)
        .whereType<String>()
        .toList();
  }

  @override
  Future<List<ProfileModel>> searchProfiles(String query, {int limit = 10}) async {
    final rows = await _service.identity
        .from(DbTables.profiles)
        .select(ProfileModel.columns)
        .ilike('username', '%$query%')
        .limit(limit);
    return rows.map(ProfileModel.fromJson).toList();
  }

  @override
  Future<void> submitOsintApplication(Map<String, dynamic> payload) async {
    try {
      await _service.identity.from(DbTables.osintApplications).insert({
        ...payload,
        'user_id': _requireUserId,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<OsintApplicationModel?> getMyApplication() async {
    final me = _service.currentUserId;
    if (me == null) return null;
    final row = await _service.identity
        .from(DbTables.osintApplications)
        .select()
        .eq('user_id', me)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : OsintApplicationModel.fromJson(row);
  }

  @override
  Future<List<OsintApplicationModel>> getAllApplications() async {
    final rows = await _service.identity
        .from(DbTables.osintApplications)
        .select()
        .order('created_at', ascending: false);
    return rows.map(OsintApplicationModel.fromJson).toList();
  }

  @override
  Future<void> setApplicationStatus(int applicationId, String status) async {
    try {
      await _service.identity
          .from(DbTables.osintApplications)
          .update({'status': status})
          .eq('id', applicationId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ex.PermissionException('Only admins can review applications.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> awardAuraPoints(String userId, int points) async {
    await _service.rpc<void>(
      DbRpc.upsertAuraPoints,
      params: {'p_user_id': userId, 'p_points': points},
    );
  }

  @override
  Future<Map<String, ProfileModel>> profilesByIds(Iterable<String?> ids) async {
    final unique = ids.whereType<String>().toSet().toList();
    if (unique.isEmpty) return const {};
    final rows = await _service.identity
        .from(DbTables.profiles)
        .select(ProfileModel.columns)
        .inFilter('id', unique);
    return {
      for (final row in rows) row['id'] as String: ProfileModel.fromJson(row),
    };
  }
}
