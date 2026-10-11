import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/story.dart';
import '../entities/story_publication.dart';
import '../repositories/story_ai_repository.dart';
import '../repositories/story_repository.dart';

class PublishIntelParams {
  const PublishIntelParams({
    required this.body,
    required this.tag,
    required this.region,
    this.regionLat,
    this.regionLng,
    this.attachToStoryId,
    this.headline,
    this.summary,
  });

  final String body;
  final String tag;
  final String region;
  final double? regionLat;
  final double? regionLng;

  /// When set, the post is attached to this existing story (the web's
  /// threadId) instead of being auto-clustered.
  final int? attachToStoryId;
  final String? headline;
  final String? summary;
}

/// Publishes an intelligence report the same way the web `useStoryComposer`
/// does, with the database doing the parts the web used to do by hand:
///   1. `story_publish` — insert as news, link / attach, clean duplicates,
///      keyword headline for a new story (no polling: links are set in the
///      same transaction);
///   2. new story → AI headline + summary from this post;
///   3. existing story (thread or cluster) → AI summary refreshed over all
///      of its sources;
///   4. `story_set_meta` saves whatever the AI produced.
/// Steps 2–4 are best effort: if the AI is down the story keeps its keyword
/// metadata and the publish still succeeds.
class PublishIntel implements UseCase<Story?, PublishIntelParams> {
  const PublishIntel(this._stories, this._ai);

  static const int minBodyLength = 20;

  final StoryRepository _stories;
  final StoryAiRepository _ai;

  @override
  Future<Result<Story?>> call(PublishIntelParams params) async {
    final body = params.body.trim();
    if (body.length < minBodyLength) {
      return const Err(ValidationFailure(
        'An intelligence report needs at least 20 characters.',
      ));
    }
    if (params.tag.isEmpty) {
      return const Err(ValidationFailure('Pick a tag for this report.'));
    }

    final published = await _stories.publishPost(
      body: body,
      tag: params.tag,
      region: params.region.isEmpty ? 'Global' : params.region,
      regionLat: params.regionLat,
      regionLng: params.regionLng,
      threadId: params.attachToStoryId,
      headline: _clean(params.headline),
      summary: _clean(params.summary),
    );
    final publication = published.valueOrNull;
    if (publication == null) {
      return Err(published.failureOrNull ?? const UnexpectedFailure());
    }

    final storyId = publication.storyId;
    if (storyId == null) return const Ok(null);

    if (publication.needsAiMeta || publication.needsSummaryRefresh) {
      await _writeWithAi(storyId, publication, params);
    }

    // The post is live either way; a failed re-read just means no preview.
    return Ok((await _stories.getStory(storyId)).valueOrNull);
  }

  Future<void> _writeWithAi(
    int storyId,
    StoryPublication publication,
    PublishIntelParams params,
  ) async {
    final context = (await _stories.getStoryContext(storyId)).valueOrNull;
    if (context == null || context.sources.isEmpty) return;

    if (publication.needsAiMeta) {
      final headline =
          _clean(params.headline) ?? await _ai.generateHeadline(context.sources);
      final summary = _clean(params.summary) ??
          await _ai.generateSummary(
              headline ?? params.body.trim(), context.sources);
      if (headline != null || summary != null) {
        await _stories.setStoryMeta(storyId,
            headline: headline, summary: summary);
      }
      return;
    }

    final summary = await _ai.generateSummary(
        context.headline.isEmpty ? (params.headline ?? '') : context.headline,
        context.sources);
    if (summary != null) {
      await _stories.setStoryMeta(storyId, summary: summary);
    }
  }

  static String? _clean(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }
}
