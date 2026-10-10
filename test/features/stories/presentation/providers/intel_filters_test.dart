import 'package:flutter_test/flutter_test.dart';
import 'package:mint/core/constants/app_constants.dart';
import 'package:mint/features/stories/domain/entities/story.dart';
import 'package:mint/features/stories/presentation/providers/story_provider.dart';

Story _story({String? tag, int confidence = 50, bool breaking = false}) =>
    Story(
      id: 1,
      headline: 'h',
      createdAt: DateTime(2026),
      tag: tag,
      confidence: confidence,
      isBreaking: breaking,
    );

void main() {
  group('IntelFilters', () {
    test('no filters match everything and are not active', () {
      expect(IntelFilters.none.isActive, isFalse);
      expect(IntelFilters.none.matches(_story()), isTrue);
    });

    test('topics match loosely tagged stories', () {
      const f = IntelFilters(topics: {'GEOPOLITICS', 'CONFLICT'});
      expect(f.matches(_story(tag: 'Geopolitical')), isTrue);
      expect(f.matches(_story(tag: 'GEOPOLITICS')), isTrue);
      expect(f.matches(_story(tag: 'conflicts')), isTrue);
      expect(f.matches(_story(tag: 'Economic')), isFalse);
      expect(f.matches(_story()), isFalse);
    });

    test('confidence and breaking only', () {
      const high = IntelFilters(minConfidence: MinConfidence.high);
      expect(high.matches(_story(confidence: 70)), isTrue);
      expect(high.matches(_story(confidence: 69)), isFalse);
      const medium = IntelFilters(minConfidence: MinConfidence.medium);
      expect(medium.matches(_story(confidence: 55)), isTrue);
      expect(medium.matches(_story(confidence: 54)), isFalse);
      const breaking = IntelFilters(breakingOnly: true);
      expect(breaking.matches(_story(breaking: true)), isTrue);
      expect(breaking.matches(_story()), isFalse);
    });

    test('equality ignores topic order; any change makes it active', () {
      expect(const IntelFilters(topics: {'A', 'B'}),
          const IntelFilters(topics: {'B', 'A'}));
      expect(const IntelFilters(window: TimeWindow.week).isActive, isTrue);
    });
  });
}
