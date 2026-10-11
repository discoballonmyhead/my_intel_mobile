import '../../../../core/utils/result.dart';
import '../entities/story.dart';
import '../entities/story_publication.dart';

abstract interface class StoryRepository {
  /// Stories with their sources and each source's author attached.
  Future<Result<List<Story>>> getStories({int limit = 50});

  Future<Result<Story>> getStory(int storyId);

  /// Full-text search over `content.stories.fts`, falling back to an ILIKE on
  /// the headline when FTS returns nothing.
  Future<Result<List<Story>>> searchStories(String query, {int limit = 15});

  Future<Result<List<Story>>> getRecentStories({int limit = 20});

  /// Stories an analyst has contributed at least one source to.
  Future<Result<List<Story>>> getStoriesByContributor(String userId);

  /// Publishes an OSINT news post via `story_publish` (shared with the web):
  /// the post keeps `post_type = 'news'`, [threadId] attaches it to that
  /// story, otherwise the clustering trigger links it; duplicate links are
  /// cleaned up and a new story gets keyword metadata straight away.
  Future<Result<StoryPublication>> publishPost({
    required String body,
    required String tag,
    String? region,
    double? regionLat,
    double? regionLng,
    int? threadId,
    String? headline,
    String? summary,
  });

  /// Updates a story's text / place. Null arguments are left unchanged.
  /// Allowed for contributors of the story and staff.
  Future<Result<void>> setStoryMeta(
    int storyId, {
    String? headline,
    String? summary,
    String? tag,
    String? region,
    double? regionLat,
    double? regionLng,
  });

  /// Headline + every source post (oldest first) for an AI summary refresh.
  Future<Result<StoryContext>> getStoryContext(int storyId);

  /// Region roll-up used by the map: name, coordinates, story count.
  Future<Result<List<RegionActivity>>> getRegionActivity();
}

/// Aggregate of stories per region, derived client-side from the story rows.
class RegionActivity {
  const RegionActivity({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.count,
    required this.hasBreaking,
  });

  final String name;
  final double latitude;
  final double longitude;
  final int count;
  final bool hasBreaking;

  bool get isBusy => count >= 8;
}
