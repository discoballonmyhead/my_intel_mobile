import '../../../../core/error/failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../profile/data/datasources/profile_remote_data_source.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../stories/data/models/story_model.dart';
import '../../../stories/domain/entities/story.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._remote, this._profiles);

  final SearchRemoteDataSource _remote;
  final ProfileRemoteDataSource _profiles;

  @override
  Future<Result<SearchResults>> search(SearchQuery query) {
    return guard(() async {
      // Three independent queries — run them together rather than in sequence.
      final results = await Future.wait([
        _remote.searchStories(query),
        _remote.searchPosts(query),
        _remote.searchProfiles(query),
      ]);

      final storyRows = results[0];
      final postRows = results[1];
      final profileRows = results[2];

      // Post authors live in `identity`, so attach them in one extra batch.
      final authors = await _profiles
          .profilesByIds(postRows.map((r) => r['author_id'] as String?));

      return SearchResults(
        stories: storyRows
            .map((row) => StoryModel.fromJson(row) as Story)
            .toList(),
        posts: postRows
            .map((row) => PostModel.fromJson(
                  row,
                  author: authors[row['author_id']],
                ) as Post)
            .toList(),
        profiles: profileRows
            .map((row) => ProfileModel.fromJson(row) as Profile)
            .toList(),
      );
    });
  }
}
