import 'dart:developer' as dev;

import '../../domain/entities/story_publication.dart';
import '../../domain/repositories/story_ai_repository.dart';
import '../datasources/story_ai_remote_data_source.dart';
import '../story_ai_prompts.dart';

class StoryAiRepositoryImpl implements StoryAiRepository {
  StoryAiRepositoryImpl(this._remote);
  final StoryAiRemoteDataSource _remote;

  @override
  Future<String?> generateHeadline(List<StorySourceText> sources) => _ask(
        StoryAiPrompts.headline(sources),
        StoryAiPrompts.headlineMaxTokens,
        sources,
      );

  @override
  Future<String?> generateSummary(
          String headline, List<StorySourceText> sources) =>
      _ask(
        StoryAiPrompts.summary(headline, sources),
        StoryAiPrompts.summaryMaxTokens,
        sources,
      );

  Future<String?> _ask(
      String prompt, int maxTokens, List<StorySourceText> sources) async {
    if (sources.isEmpty) return null;
    try {
      return await _remote.complete(
        model: StoryAiPrompts.model,
        prompt: prompt,
        maxTokens: maxTokens,
      );
    } catch (e) {
      // Same as the web: AI is optional, the story keeps its keyword text.
      dev.log('story AI unavailable: $e', name: 'StoryAiRepository');
      return null;
    }
  }
}
