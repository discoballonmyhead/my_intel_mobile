import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';

abstract interface class ModerationRemoteDataSource {
  Future<Map<String, dynamic>?> fetchClaimForPost(int postId);
  Future<List<Map<String, dynamic>>> fetchNotesForPost(int postId);
  Future<Map<String, dynamic>> insertNote(Map<String, dynamic> payload);
  Future<Map<String, dynamic>> updateNote(
      int noteId, Map<String, dynamic> payload);
  Future<void> deleteNote(int noteId);
  Future<List<Map<String, dynamic>>> fetchOpenClaims();
  Future<void> updateClaim(int claimId, Map<String, dynamic> payload);
  Future<void> rateNote(int noteId, String accuracyRating);
  Future<void> insertFeedback(Map<String, dynamic> payload);
}

class ModerationRemoteDataSourceImpl implements ModerationRemoteDataSource {
  ModerationRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<Map<String, dynamic>?> fetchClaimForPost(int postId) async {
    final res = await _service
        .rpc('mod_get_claim_for_post', params: {'p_post_id': postId});
    return res as Map<String, dynamic>?;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotesForPost(int postId) async {
    final res = await _service.rpc<List<dynamic>>('mod_get_notes_for_post',
        params: {'p_post_id': postId});
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<Map<String, dynamic>> insertNote(Map<String, dynamic> payload) async {
    try {
      final res =
          await _service.rpc('mod_create_note', params: {'p_payload': payload});
      return res as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>> updateNote(
      int noteId, Map<String, dynamic> payload) async {
    try {
      final res = await _service.rpc('mod_update_note', params: {
        'p_note_id': noteId,
        'p_payload': payload,
      });
      return res as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      if (e.code == '42501')
        throw const ex.PermissionException(
            'Notes can only be edited by an admin.');
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<void> deleteNote(int noteId) async {
    try {
      await _service.rpc('mod_delete_note', params: {'p_note_id': noteId});
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOpenClaims() async {
    final res = await _service.rpc<List<dynamic>>('mod_get_open_claims');
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<void> updateClaim(int claimId, Map<String, dynamic> payload) async {
    try {
      await _service.rpc('mod_resolve_claim', params: {
        'p_claim_id': claimId,
        'p_payload': payload,
      });
    } on PostgrestException catch (e) {
      if (e.code == '42501')
        throw const ex.PermissionException('Only admins can resolve claims.');
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
      await _service.rpc('mod_submit_feedback', params: {'p_payload': payload});
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }
}
