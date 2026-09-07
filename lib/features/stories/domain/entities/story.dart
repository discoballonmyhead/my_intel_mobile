import 'package:equatable/equatable.dart';

import '../../../profile/domain/entities/profile.dart';

/// A row of `content.stories` — a cluster of analyst posts about one event.
/// Created either by the `auto_link_post_to_stories` trigger or explicitly by
/// an analyst through the composer.
class Story extends Equatable {
  const Story({
    required this.id,
    required this.headline,
    required this.createdAt,
    this.summary,
    this.tag,
    this.region,
    this.confidence = 0,
    this.isBreaking = false,
    this.updatedAt,
    this.regionLat,
    this.regionLng,
    this.sources = const [],
  });

  final int id;
  final String headline;
  final String? summary;
  final String? tag;
  final String? region;

  /// 0-100, maintained server-side.
  final int confidence;
  final bool isBreaking;

  final DateTime createdAt;

  /// Bumped by the `stories_updated_at` trigger whenever the story changes, so
  /// a story with a fresh source rises back up the trending list.
  final DateTime? updatedAt;

  final double? regionLat;
  final double? regionLng;

  final List<StorySource> sources;

  int get sourceCount => sources.length;

  /// A story corroborated by three or more analysts.
  bool get isCorroborated => sourceCount >= 3;

  bool get hasCoordinates => regionLat != null && regionLng != null;

  /// Timestamp trending ranks on.
  DateTime get activityAt => updatedAt ?? createdAt;

  Story copyWith({List<StorySource>? sources}) {
    return Story(
      id: id,
      headline: headline,
      summary: summary,
      tag: tag,
      region: region,
      confidence: confidence,
      isBreaking: isBreaking,
      createdAt: createdAt,
      updatedAt: updatedAt,
      regionLat: regionLat,
      regionLng: regionLng,
      sources: sources ?? this.sources,
    );
  }

  @override
  List<Object?> get props => [id, headline, confidence, isBreaking, sourceCount];
}

/// A row of `content.story_sources` joined to the post it cites.
class StorySource extends Equatable {
  const StorySource({
    required this.postId,
    this.body,
    this.author,
    this.createdAt,
  });

  final int postId;
  final String? body;
  final Profile? author;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [postId, body, author];
}

/// A story ranked for the trending list.
class RankedStory extends Equatable {
  const RankedStory({required this.story, required this.score});

  final Story story;
  final double score;

  @override
  List<Object?> get props => [story, score];
}
