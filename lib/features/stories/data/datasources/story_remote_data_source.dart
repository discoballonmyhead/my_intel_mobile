import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../models/story_model.dart';

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

  /// `public.extract_keywords(p_text)` — used to build a fallback headline.
  Future<List<String>> extractKeywords(String text);
}

class StoryRemoteDataSourceImpl implements StoryRemoteDataSource {
  StoryRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> fetchStories({int limit = 50}) async {
    try {
      return await _service.content
          .from(DbTables.stories)
          .select(StoryModel.withSourcesColumns)
          .order('created_at', ascending: false)
          .limit(limit);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchStory(int storyId) async {
    try {
      return await _service.content
          .from(DbTables.stories)
          .select(StoryModel.withSourcesColumns)
          .eq('id', storyId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchStories(
    String query, {
    int limit = 15,
  }) async {
    try {
      // Try the generated `fts` tsvector column first.
      final ftsRows = await _service.content
          .from(DbTables.stories)
          .select(StoryModel.listColumns)
          .textSearch('fts', query, config: 'english', type: TextSearchType.websearch)
          .order('created_at', ascending: false)
          .limit(limit);

      if (ftsRows.isNotEmpty) return ftsRows;

      // Fall back to a substring match so partial words still find something.
      return await _service.content
          .from(DbTables.stories)
          .select(StoryModel.listColumns)
          .ilike('headline', '%$query%')
          .order('created_at', ascending: false)
          .limit(limit);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecentStories({int limit = 20}) async {
    return _service.content
        .from(DbTables.stories)
        .select(StoryModel.listColumns)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegionRows() async {
    return _service.content
        .from(DbTables.stories)
        .select('region, region_lat, region_lng, is_breaking');
  }

  @override
  Future<List<int>> storyIdsForPost(int postId) async {
    final rows = await _service.content
        .from(DbTables.storySources)
        .select('story_id')
        .eq('post_id', postId);
    return rows
        .map((r) => (r['story_id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  @override
  Future<List<int>> storyIdsForAuthor(String authorId) async {
    // story_sources -> posts is an in-schema embed, so this one join is legal.
    final rows = await _service.content
        .from(DbTables.storySources)
        .select('story_id, posts!inner(author_id)')
        .eq('posts.author_id', authorId);
    return rows
        .map((r) => (r['story_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList();
  }

  @override
  Future<void> unlinkStorySources(int postId, List<int> storyIds) async {
    if (storyIds.isEmpty) return;
    await _service.content
        .from(DbTables.storySources)
        .delete()
        .eq('post_id', postId)
        .inFilter('story_id', storyIds);
  }

  @override
  Future<void> updateStory(int storyId, Map<String, dynamic> payload) async {
    try {
      await _service.content
          .from(DbTables.stories)
          .update(payload)
          .eq('id', storyId);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<String>> extractKeywords(String text) async {
    final result = await _service.rpc<List<dynamic>?>(
      DbRpc.extractKeywords,
      params: {'p_text': text},
    );
    return (result ?? const []).map((e) => e.toString()).toList();
  }
}
