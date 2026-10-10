import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';

abstract interface class StoryRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchStories({int limit});
  Future<Map<String, dynamic>?> fetchStory(int storyId);
  Future<List<Map<String, dynamic>>> searchStories(String query, {int limit});
  Future<List<Map<String, dynamic>>> fetchRecentStories({int limit});
  Future<List<Map<String, dynamic>>> fetchRegionRows();
  Future<List<int>> storyIdsForPost(int postId);
  Future<List<int>> storyIdsForAuthor(String authorId);
  Future<void> unlinkStorySources(int postId, List<int> storyIds);
  Future<void> updateStory(int storyId, Map<String, dynamic> payload);
  Future<List<String>> extractKeywords(String text);
}

class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  StoryRemoteDataSourceImpl(this._service);
  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> fetchStories({int limit = 50}) async {
    try {
      final res = await _service
          .rpc<List<dynamic>>('story_get_all', params: {'p_limit': limit});
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchStory(int storyId) async {
    try {
      final res = await _service
          .rpc('story_get_by_id', params: {'p_story_id': storyId});
      // The RPC returns a set (a list with one row), not a single object.
      if (res is List) {
        return res.isEmpty ? null : Map<String, dynamic>.from(res.first as Map);
      }
      return res as Map<String, dynamic>?;
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchStories(String query,
      {int limit = 15}) async {
    try {
      final res =
          await _service.rpc<List<dynamic>>('story_search_fallback', params: {
        'p_query': query,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecentStories(
      {int limit = 20}) async {
    final res = await _service.rpc<List<dynamic>>('story_get_all',
        params: {'p_limit': limit}); // reused get_all for recent
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegionRows() async {
    final res = await _service.rpc<List<dynamic>>('story_get_regions');
    return List<Map<String, dynamic>>.from(res ?? []);
  }

  @override
  Future<List<int>> storyIdsForPost(int postId) async {
    final res = await _service.rpc<List<dynamic>>('story_get_ids_for_post',
        params: {'p_post_id': postId});
    return res?.map((e) => e as int).toList() ?? [];
  }

  @override
  Future<List<int>> storyIdsForAuthor(String authorId) async {
    final res = await _service.rpc<List<dynamic>>('story_get_ids_for_author',
        params: {'p_author_id': authorId});
    return res?.map((e) => e as int).toSet().toList() ?? [];
  }

  @override
  Future<void> unlinkStorySources(int postId, List<int> storyIds) async {
    if (storyIds.isEmpty) return;
    await _service.rpc('story_unlink_sources', params: {
      'p_post_id': postId,
      'p_story_ids': storyIds,
    });
  }

  @override
  Future<void> updateStory(int storyId, Map<String, dynamic> payload) async {
    try {
      await _service.rpc('story_update', params: {
        'p_story_id': storyId,
        'p_payload': payload,
      });
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    final result = await _service
        .rpc<List<dynamic>?>('nlp_extract_keywords', params: {'p_text': text});
    return (result ?? const []).map((e) => e.toString()).toList();
  }
}
