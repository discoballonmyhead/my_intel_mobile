import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/rpc_runner.dart';
import '../../../../core/network/supabase_service.dart';

abstract interface class StoryRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchStories({int limit});
  Future<Map<String, dynamic>?> fetchStory(int storyId);
  Future<List<Map<String, dynamic>>> searchStories(String query, {int limit});
  Future<List<Map<String, dynamic>>> fetchRecentStories({int limit});
  Future<List<Map<String, dynamic>>> fetchRegionRows();
  Future<List<int>> storyIdsForAuthor(String authorId);

  /// `story_publish` (migration 12) — the raw jsonb result.
  Future<Map<String, dynamic>> publish({
    required String body,
    required String tag,
    String? region,
    double? regionLat,
    double? regionLng,
    int? threadId,
    String? headline,
    String? summary,
  });

  /// `story_set_meta` — replaces direct `stories` updates.
  Future<void> setMeta(
    int storyId, {
    String? headline,
    String? summary,
    String? tag,
    String? region,
    double? regionLat,
    double? regionLng,
  });

  /// `story_get_context` — {story, sources: [{body, username, …}]}.
  Future<Map<String, dynamic>> fetchContext(int storyId);
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
  Future<List<int>> storyIdsForAuthor(String authorId) async {
    final res = await _service.rpc<List<dynamic>>('story_get_ids_for_author',
        params: {'p_author_id': authorId});
    return res?.map((e) => e as int).toSet().toList() ?? [];
  }

  @override
  Future<Map<String, dynamic>> publish({
    required String body,
    required String tag,
    String? region,
    double? regionLat,
    double? regionLng,
    int? threadId,
    String? headline,
    String? summary,
  }) =>
      runRpc(() async {
        final res = await _service.rpc<dynamic>(StoryRpc.publish, params: {
          'p_body': body,
          'p_tag': tag,
          'p_region': region,
          'p_region_lat': regionLat,
          'p_region_lng': regionLng,
          'p_thread_id': threadId,
          'p_headline': headline,
          'p_summary': summary,
        });
        return asRow(res) ??
            (throw const ex.ServerException('The report was not published.'));
      });

  @override
  Future<void> setMeta(
    int storyId, {
    String? headline,
    String? summary,
    String? tag,
    String? region,
    double? regionLat,
    double? regionLng,
  }) =>
      runRpc(() async {
        await _service.rpc<dynamic>(StoryRpc.setMeta, params: {
          'p_story_id': storyId,
          'p_headline': headline,
          'p_summary': summary,
          'p_tag': tag,
          'p_region': region,
          'p_region_lat': regionLat,
          'p_region_lng': regionLng,
        });
      });

  @override
  Future<Map<String, dynamic>> fetchContext(int storyId) => runRpc(() async {
        final res = await _service.rpc<dynamic>(StoryRpc.context,
            params: {'p_story_id': storyId});
        return asRow(res) ??
            (throw const ex.NotFoundException('Story not found.'));
      });
}
