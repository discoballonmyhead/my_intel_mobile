import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/story.dart';
import '../repositories/story_repository.dart';

class GetStories implements UseCase<List<Story>, NoParams> {
  const GetStories(this._repository);

  final StoryRepository _repository;

  @override
  Future<Result<List<Story>>> call(NoParams params) => _repository.getStories();
}

class GetStory implements UseCase<Story, int> {
  const GetStory(this._repository);

  final StoryRepository _repository;

  @override
  Future<Result<Story>> call(int storyId) => _repository.getStory(storyId);
}

class SearchStories implements UseCase<List<Story>, String> {
  const SearchStories(this._repository);

  final StoryRepository _repository;

  @override
  Future<Result<List<Story>>> call(String query) =>
      _repository.searchStories(query.trim());
}

class GetRegionActivity implements UseCase<List<RegionActivity>, NoParams> {
  const GetRegionActivity(this._repository);

  final StoryRepository _repository;

  @override
  Future<Result<List<RegionActivity>>> call(NoParams params) =>
      _repository.getRegionActivity();
}
