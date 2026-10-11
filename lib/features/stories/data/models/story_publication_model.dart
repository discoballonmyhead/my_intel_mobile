import '../../../../core/network/rpc_runner.dart';
import '../../domain/entities/story_publication.dart';

class StoryPublicationModel extends StoryPublication {
  const StoryPublicationModel({
    required super.postId,
    required super.mode,
    super.storyId,
    super.isNewStory,
    super.needsAiMeta,
    super.needsSummaryRefresh,
  });

  /// jsonb from `story_publish`.
  factory StoryPublicationModel.fromJson(Map<String, dynamic> json) {
    return StoryPublicationModel(
      postId: asInt(json['post_id']) ?? 0,
      mode: StoryLinkMode.fromValue(json['mode'] as String?),
      storyId: asInt(json['story_id']),
      isNewStory: json['story_is_new'] as bool? ?? false,
      needsAiMeta: json['needs_ai_meta'] as bool? ?? false,
      needsSummaryRefresh: json['needs_summary_refresh'] as bool? ?? false,
    );
  }
}

class StoryContextModel extends StoryContext {
  const StoryContextModel({
    required super.storyId,
    required super.headline,
    super.sources,
  });

  /// jsonb from `story_get_context`: `{story: {...}, sources: [...]}`.
  factory StoryContextModel.fromJson(Map<String, dynamic> json) {
    final story = json['story'];
    final s = story is Map ? story : const {};
    final rawSources = json['sources'];
    return StoryContextModel(
      storyId: asInt(s['id']) ?? 0,
      headline: (s['headline'] as String?) ?? '',
      sources: [
        if (rawSources is List)
          for (final src in rawSources.whereType<Map>())
            if ((src['body'] as String?)?.trim().isNotEmpty ?? false)
              StorySourceText(
                body: (src['body'] as String).trim(),
                username: src['username'] as String?,
              ),
      ],
    );
  }
}
