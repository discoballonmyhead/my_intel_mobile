import '../../../../core/utils/result.dart';
import '../entities/search_results.dart';

abstract interface class SearchRepository {
  Future<Result<SearchResults>> search(SearchQuery query);
}
