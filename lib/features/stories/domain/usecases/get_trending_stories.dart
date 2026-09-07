import '../../../../core/constants/app_constants.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/story.dart';
import '../repositories/story_repository.dart';
import '../services/trending_ranker.dart';

class TrendingParams {
  const TrendingParams({this.window = TimeWindow.day, this.tag});
  final TimeWindow window;
  final String? tag;
}

/// Fetches stories and applies the time-decay ranking. Composing the ranker
/// here keeps the ordering rule out of both the repository and the widget.
class GetTrendingStories implements UseCase<List<RankedStory>, TrendingParams> {
  const GetTrendingStories(this._repository, this._ranker);

  final StoryRepository _repository;
  final TrendingRanker _ranker;

  @override
  Future<Result<List<RankedStory>>> call(TrendingParams params) async {
    final result = await _repository.getStories();
    return result.map((stories) {
      final filtered = params.tag == null || params.tag == 'ALL'
          ? stories
          : stories.where((s) => s.tag == params.tag).toList();
      return _ranker.rank(filtered, window: params.window);
    });
  }
}
