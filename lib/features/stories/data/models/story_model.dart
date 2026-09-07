import '../../../../core/utils/date_x.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/story.dart';

class StoryModel extends Story {
  const StoryModel({
    required super.id,
    required super.headline,
    required super.createdAt,
    super.summary,
    super.tag,
    super.region,
    super.confidence,
    super.isBreaking,
    super.updatedAt,
    super.regionLat,
    super.regionLng,
    super.sources,
  });

  /// [authors] maps a post author id to their profile — resolved separately
  /// because `content.posts.author_id` crosses into the `identity` schema.
  factory StoryModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, Profile> authors = const {},
  }) {
    final rawSources = (json['story_sources'] as List?) ?? const [];

    return StoryModel(
      id: (json['id'] as num).toInt(),
      headline: (json['headline'] as String?) ?? '',
      summary: json['summary'] as String?,
      tag: json['tag'] as String?,
      region: json['region'] as String?,
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      isBreaking: (json['is_breaking'] as bool?) ?? false,
      createdAt: parseTimestamp(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: parseTimestamp(json['updated_at']),
      regionLat: (json['region_lat'] as num?)?.toDouble(),
      regionLng: (json['region_lng'] as num?)?.toDouble(),
      sources: rawSources
          .whereType<Map<String, dynamic>>()
          .map((s) => StorySourceModel.fromJson(s, authors: authors))
          .toList(),
    );
  }

  /// Columns needed for a list row (no sources).
  static const String listColumns =
      'id, headline, summary, tag, region, confidence, is_breaking, created_at, updated_at, region_lat, region_lng';

  /// story_sources and posts are both in `content`, so that embed is legal.
  static const String withSourcesColumns = '''
    *,
    story_sources (
      post_id,
      posts ( id, body, created_at, author_id )
    )
  ''';
}

class StorySourceModel extends StorySource {
  const StorySourceModel({
    required super.postId,
    super.body,
    super.author,
    super.createdAt,
  });

  factory StorySourceModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, Profile> authors = const {},
  }) {
    final post = json['posts'] as Map<String, dynamic>?;
    final authorId = post?['author_id'] as String?;

    return StorySourceModel(
      postId: (json['post_id'] as num?)?.toInt() ??
          (post?['id'] as num?)?.toInt() ??
          0,
      body: post?['body'] as String?,
      author: authorId == null ? null : authors[authorId],
      createdAt: parseTimestamp(post?['created_at']),
    );
  }

  /// Pulls every author id out of an embedded story row so they can be
  /// fetched in one batch.
  static Iterable<String?> authorIdsOf(Map<String, dynamic> storyJson) {
    final sources = (storyJson['story_sources'] as List?) ?? const [];
    return sources.whereType<Map<String, dynamic>>().map(
          (s) => (s['posts'] as Map<String, dynamic>?)?['author_id'] as String?,
        );
  }
}
