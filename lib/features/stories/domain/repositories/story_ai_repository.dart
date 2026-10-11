import '../entities/story_publication.dart';

/// Headline / summary writing for stories, through the same `anthropic-proxy`
/// edge function and prompts as the web composer. Best effort: every method
/// returns null instead of failing, because publishing must never depend on
/// the AI being available.
abstract interface class StoryAiRepository {
  /// Verb-first, 8–12 word headline.
  Future<String?> generateHeadline(List<StorySourceText> sources);

  /// 2–4 sentence situation summary across all [sources].
  Future<String?> generateSummary(
      String headline, List<StorySourceText> sources);
}
