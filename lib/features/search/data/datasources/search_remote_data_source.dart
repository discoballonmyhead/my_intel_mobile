import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart' as ex;
import '../../../../core/network/supabase_service.dart';
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
      final res =
          await _service.rpc<List<dynamic>>('search_stories_query', params: {
        'p_query': query.normalised,
        'p_is_tag': query.isTagQuery,
        'p_tag': query.tag,
        'p_cutoff': query.cutoff?.toIso8601String(),
        'p_limit': AppConstants.searchPageSize,
      });
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchPosts(SearchQuery query) async {
    try {
      final res =
          await _service.rpc<List<dynamic>>('search_posts_query', params: {
        'p_query': query.normalised,
        'p_is_tag': query.isTagQuery,
        'p_tag': query.tag,
        'p_cutoff': query.cutoff?.toIso8601String(),
        'p_limit': AppConstants.searchPageSize,
      });
      return List<Map<String, dynamic>>.from(res ?? []);
    } on PostgrestException catch (e) {
      throw ex.ServerException(e.message, code: e.code);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> searchProfiles(SearchQuery query) async {
    final res =
        await _service.rpc<List<dynamic>>('search_profiles_query', params: {
      'p_query': query.normalised,
      'p_limit': 10,
    });
    return List<Map<String, dynamic>>.from(res ?? []);
  }
}
