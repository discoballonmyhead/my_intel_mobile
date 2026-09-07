import 'dart:math' as math;

import '../../../../core/constants/app_constants.dart';
import '../entities/story.dart';

/// Ranks stories with a HackerNews-style time decay.
///
///   score = (sources + 1) / (hours_since_activity + 2)^gravity
///           × breaking boost × confidence factor
///
/// Pure domain logic with no I/O, which makes it directly unit-testable —
/// the ordering rule is the product decision here, not a rendering detail.
class TrendingRanker {
  const TrendingRanker({
    this.gravity = 1.5,
    this.breakingBoost = 2.0,
  });

  final double gravity;
  final double breakingBoost;

  double scoreFor(Story story, {DateTime? now}) {
    final reference = now ?? DateTime.now().toUtc();
    final hoursOld =
        reference.difference(story.activityAt.toUtc()).inMinutes / 60.0;

    final base = (story.sourceCount + 1) /
        math.pow(math.max(hoursOld, 0) + 2, gravity);

    final breaking = story.isBreaking ? breakingBoost : 1.0;

    // 100% confidence scores 1.0x, 0% scores 0.5x.
    final confidence = (story.confidence / 100) * 0.5 + 0.5;

    return base * breaking * confidence;
  }

  List<RankedStory> rank(
    List<Story> stories, {
    TimeWindow window = TimeWindow.day,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now().toUtc();
    final cutoff = window.duration == null
        ? null
        : reference.subtract(window.duration!);

    final ranked = stories
        .where((s) => cutoff == null || !s.activityAt.toUtc().isBefore(cutoff))
        .map((s) => RankedStory(story: s, score: scoreFor(s, now: reference)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return ranked;
  }
}
