import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/story.dart';
import '../../domain/usecases/get_stories.dart';
import '../../domain/usecases/get_trending_stories.dart';
import '../../domain/usecases/publish_intel.dart';

enum StoryStatus { initial, loading, ready, error }

/// Lowest confidence a story needs to be shown.
enum MinConfidence {
  any('Any', 0),
  medium('Medium+', 55),
  high('High only', 70);

  const MinConfidence(this.label, this.value);
  final String label;
  final int value;
}

/// Everything the Intel filter sheet controls. An empty [topics] set means all
/// topics.
@immutable
class IntelFilters {
  const IntelFilters({
    this.topics = const {},
    this.window = TimeWindow.all,
    this.minConfidence = MinConfidence.any,
    this.breakingOnly = false,
  });

  final Set<String> topics;
  final TimeWindow window;
  final MinConfidence minConfidence;
  final bool breakingOnly;

  static const none = IntelFilters();

  bool get isActive =>
      topics.isNotEmpty ||
      window != TimeWindow.all ||
      minConfidence != MinConfidence.any ||
      breakingOnly;

  /// Stories are tagged loosely ("GEOPOLITICAL", "CONFLICTS"), so compare
  /// stems: "GEOPOLITICS" and "GEOPOLITICAL" both become "GEOPOLITIC".
  static String _stem(String tag) {
    var t = tag.trim().toUpperCase();
    if (t.endsWith('S')) t = t.substring(0, t.length - 1);
    if (t.endsWith('AL')) t = t.substring(0, t.length - 2);
    return t;
  }

  bool matches(Story s) =>
      (topics.isEmpty ||
          (s.tag != null && topics.map(_stem).contains(_stem(s.tag!)))) &&
      s.confidence >= minConfidence.value &&
      (!breakingOnly || s.isBreaking);

  IntelFilters copyWith({
    Set<String>? topics,
    TimeWindow? window,
    MinConfidence? minConfidence,
    bool? breakingOnly,
  }) =>
      IntelFilters(
        topics: topics ?? this.topics,
        window: window ?? this.window,
        minConfidence: minConfidence ?? this.minConfidence,
        breakingOnly: breakingOnly ?? this.breakingOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is IntelFilters &&
      setEquals(other.topics, topics) &&
      other.window == window &&
      other.minConfidence == minConfidence &&
      other.breakingOnly == breakingOnly;

  @override
  int get hashCode => Object.hash(
      Object.hashAllUnordered(topics), window, minConfidence, breakingOnly);
}

class StoryProvider extends ChangeNotifier {
  StoryProvider({
    required GetStories getStories,
    required GetTrendingStories getTrending,
    required PublishIntel publishIntel,
  })  : _getStories = getStories,
        _getTrending = getTrending,
        _publishIntel = publishIntel;

  final GetStories _getStories;
  final GetTrendingStories _getTrending;
  final PublishIntel _publishIntel;

  List<RankedStory> _ranked = const [];
  StoryStatus _status = StoryStatus.initial;
  Failure? _failure;
  IntelFilters _filters = IntelFilters.none;
  bool _following = false;
  bool _publishing = false;

  List<RankedStory> get ranked => _ranked;
  List<Story> get stories => _ranked.map((r) => r.story).toList();

  /// [stories] after the client-side filters. Following needs a backend query
  /// that doesn't exist yet, so it is empty for now.
  List<Story> get visibleStories =>
      _following ? const [] : stories.where(_filters.matches).toList();
  StoryStatus get status => _status;
  Failure? get failure => _failure;
  IntelFilters get filters => _filters;
  bool get following => _following;
  bool get publishing => _publishing;
  bool get isEmpty => _ranked.isEmpty && _status == StoryStatus.ready;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _status = StoryStatus.loading;
      notifyListeners();
    }

    final result = await _getTrending(TrendingParams(window: _filters.window));
    result.fold(
      (failure) {
        _failure = failure;
        _status = StoryStatus.error;
      },
      (ranked) {
        _ranked = ranked;
        _failure = null;
        _status = StoryStatus.ready;
      },
    );
    notifyListeners();
  }

  Future<void> setFilters(IntelFilters filters) async {
    if (filters == _filters) return;
    // Topics, confidence and breaking are applied in [visibleStories]; only
    // the time window needs a new fetch.
    final refetch = filters.window != _filters.window;
    _filters = filters;
    notifyListeners();
    if (refetch) await load(silent: true);
  }

  void setFollowing(bool following) {
    if (_following == following) return;
    _following = following;
    notifyListeners();
  }

  Future<void> refresh() => load(silent: true);

  /// Unranked chronological list, for screens that want publication order.
  Future<List<Story>> loadChronological() async {
    final result = await _getStories(const NoParams());
    return result.valueOrNull ?? const [];
  }

  Future<bool> publish(PublishIntelParams params) async {
    _publishing = true;
    notifyListeners();

    final result = await _publishIntel(params);
    _publishing = false;

    final failure = result.failureOrNull;
    if (failure != null) {
      _failure = failure;
      notifyListeners();
      return false;
    }

    await load(silent: true);
    return true;
  }
}
