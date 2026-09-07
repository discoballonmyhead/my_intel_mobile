import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';

abstract interface class ModerationRemoteDataSource {
  Future<Map<String, dynamic>?> fetchClaimForPost(int postId);
  Future<List<Map<String, dynamic>>> fetchNotesForPost(int postId);
  Future<Map<String, dynamic>> insertNote(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateNote(int noteId, Map<String, dynamic> payload);
  Future<void> deleteNote(int noteId);

  Future<List<Map<String, dynamic>>> fetchOpenClaims();
  Future<void> updateClaim(int claimId, Map<String, dynamic> payload);
  Future<void> rateNote(int noteId, String accuracyRating);

  Future<void> insertFeedback(Map<String, dynamic> payload);
}

class ModerationRemoteDataSourceImpl implements ModerationRemoteDataSource {
  ModerationRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  String get _requireUserId {
    final id = _service.currentUserId;
    if (id == null) throw const ex.AuthException('You must be signed in.');
    return id;
  }

  @override
  Future<Map<String, dynamic>?> fetchClaimForPost(int postId) async {
    return _service.moderation
        .from(DbTables.claims)
        .select()
        .eq('post_id', postId)
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotesForPost(int postId) async {
    return _service.moderation
        .from(DbTables.communityNotes)
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: false);
  }

  @override
  Future<Map<String, dynamic>> insertNote(Map<String, dynamic> payload) async {
    try {
      return await _service.moderation
          .from(DbTables.communityNotes)
          .insert(payload)
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> updateNote(
    int noteId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _service.moderation
          .from(DbTables.communityNotes)
          .update(payload)
          .eq('id', noteId)
          .select()
          .single();
    } on PostgrestException catch (e) {
      // Only admins hold UPDATE on community_notes.
      if (e.code == '42501') {
        throw const ex.PermissionException('Notes can only be edited by an admin.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> deleteNote(int noteId) async {
    try {
      await _service.moderation
          .from(DbTables.communityNotes)
          .delete()
          .eq('id', noteId);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOpenClaims() async {
    return _service.moderation
        .from(DbTables.claims)
        .select()
        .eq('status', 'open')
        .order('created_at', ascending: false);
  }

  @override
  Future<void> updateClaim(int claimId, Map<String, dynamic> payload) async {
    try {
      await _service.moderation
          .from(DbTables.claims)
          .update({...payload, 'resolved_by': _requireUserId})
          .eq('id', claimId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ex.PermissionException('Only admins can resolve claims.');
      }
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> rateNote(int noteId, String accuracyRating) async {
    await updateNote(noteId, {'accuracy_rating': accuracyRating});
  }

  @override
  Future<void> insertFeedback(Map<String, dynamic> payload) async {
    try {
      await _service.moderation.from(DbTables.feedback).insert({
        ...payload,
        'user_id': _service.currentUserId,
      });
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }
}
