import 'package:equatable/equatable.dart';

/// How a published post ended up linked to a story.
enum StoryLinkMode {
  /// Attached to the story the analyst picked (manual_story_id).
  thread,

  /// The clustering trigger linked it (new or existing story).
  auto,

  /// No story yet.
  none;

  static StoryLinkMode fromValue(String? value) => switch (value) {
        'thread' => StoryLinkMode.thread,
        'auto' => StoryLinkMode.auto,
        _ => StoryLinkMode.none,
      };
}

/// Result of `story_publish`: what happened and what the client should do
/// next to finish the story's text.
class StoryPublication extends Equatable {
  const StoryPublication({
    required this.postId,
    required this.mode,
    this.storyId,
    this.isNewStory = false,
    this.needsAiMeta = false,
    this.needsSummaryRefresh = false,
  });

  final int postId;
  final StoryLinkMode mode;
  final int? storyId;

  /// This post opened the story.
  final bool isNewStory;

  /// New story whose headline/summary is still the keyword fallback.
  final bool needsAiMeta;

  /// The post joined an existing story; its summary should cover it now.
  final bool needsSummaryRefresh;

  @override
  List<Object?> get props =>
      [postId, mode, storyId, isNewStory, needsAiMeta, needsSummaryRefresh];
}

/// One source line given to the AI: who said what, oldest first.
class StorySourceText extends Equatable {
  const StorySourceText({required this.body, this.username});

  final String body;
  final String? username;

  @override
  List<Object?> get props => [body, username];
}

/// A story's headline plus all its source posts (`story_get_context`).
class StoryContext extends Equatable {
  const StoryContext({
    required this.storyId,
    required this.headline,
    this.sources = const [],
  });

  final int storyId;
  final String headline;
  final List<StorySourceText> sources;

  @override
  List<Object?> get props => [storyId, headline, sources];
}
