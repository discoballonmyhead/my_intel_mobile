import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/search_results.dart';
import '../repositories/search_repository.dart';

class SearchParams {
  const SearchParams({
    required this.text,
    this.tag,
    this.window = TimeWindow.all,
  });

  final String text;
  final String? tag;
  final TimeWindow window;
}

class SearchAll implements UseCase<SearchResults, SearchParams> {
  const SearchAll(this._repository);

  final SearchRepository _repository;

  @override
  Future<Result<SearchResults>> call(SearchParams params) async {
    final query = SearchQuery(
      text: params.text.trim(),
      tag: params.tag,
      cutoff: params.window.cutoff,
    );

    if (!query.isValid) {
      // Not an error — just nothing to search for yet.
      return const Ok(SearchResults());
    }
    if (query.normalised.length > 120) {
      return const Err(ValidationFailure('That search is too long.'));
    }

    return _repository.search(query);
  }
}
