import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/db_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../stories/data/models/story_model.dart';
import '../../domain/entities/search_results.dart';

abstract interface class SearchRemoteDataSource {
  Future<List<Map<String, dynamic>>> searchStories(SearchQuery query);
  Future<List<Map<String, dynamic>>> searchPosts(SearchQuery query);
  Future<List<Map<String, dynamic>>> searchProfiles(SearchQuery query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  SearchRemoteDataSourceImpl(this._service);

  final SupabaseService _service;

  @override
  Future<List<Map<String, dynamic>>> searchStories(SearchQuery query) async {
    try {
      var builder = _service.content
          .from(DbTables.stories)
          .select(StoryModel.listColumns);

      builder = query.isTagQuery
          ? builder.ilike('tag', '%${query.normalised}%')
          : builder.textSearch(
              'fts',
              query.normalised,
              config: 'english',
              type: TextSearchType.websearch,
            );

      if (query.tag != null) builder = builder.ilike('tag', '%${query.tag}%');
      if (query.cutoff != null) {
        builder = builder.gte('created_at', query.cutoff!.toIso8601String());
      }

      return await builder.limit(AppConstants.searchPageSize);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchPosts(SearchQuery query) async {
    try {
      var builder = _service.content
          .from(DbTables.posts)
          .select()
          .eq('is_osint', false);

      builder = query.isTagQuery
          ? builder.ilike('tag', '%${query.normalised}%')
          : builder.textSearch(
              'fts',
              query.normalised,
              config: 'english',
              type: TextSearchType.websearch,
            );

      if (query.tag != null) builder = builder.ilike('tag', '%${query.tag}%');
      if (query.cutoff != null) {
        builder = builder.gte('created_at', query.cutoff!.toIso8601String());
      }

      return await builder.limit(AppConstants.searchPageSize);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(SearchQuery query) async {
    // Usernames are not in any tsvector, so this stays a substring match.
    return _service.identity
        .from(DbTables.profiles)
        .select(ProfileModel.columns)
        .ilike('username', '%${query.normalised}%')
        .limit(10);
  }
}
