import '../../../../core/utils/result.dart';
import '../entities/story.dart';

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

  /// Publishes an analyst post. The `trg_auto_link_post_to_stories` trigger
  /// then either attaches it to an existing story or opens a new one, so the
  /// repository polls briefly for the resulting link.
  Future<Result<Story?>> publishIntel({
    required String body,
    required String tag,
    required String region,
    double? regionLat,
    double? regionLng,
    int? attachToStoryId,
    String? headline,
    String? summary,
  });

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
