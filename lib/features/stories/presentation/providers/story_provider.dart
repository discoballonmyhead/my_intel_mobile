import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/story.dart';
import '../../domain/usecases/get_stories.dart';
import '../../domain/usecases/get_trending_stories.dart';
import '../../domain/usecases/publish_intel.dart';

enum StoryStatus { initial, loading, ready, error }

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
  TimeWindow _window = TimeWindow.day;
  String _tag = 'ALL';
  bool _publishing = false;

  List<RankedStory> get ranked => _ranked;
  List<Story> get stories => _ranked.map((r) => r.story).toList();
  StoryStatus get status => _status;
  Failure? get failure => _failure;
  TimeWindow get window => _window;
  String get tag => _tag;
  bool get publishing => _publishing;
  bool get isEmpty => _ranked.isEmpty && _status == StoryStatus.ready;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _status = StoryStatus.loading;
      notifyListeners();
    }

    final result = await _getTrending(TrendingParams(window: _window, tag: _tag));
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

  Future<void> setWindow(TimeWindow window) async {
    if (_window == window) return;
    _window = window;
    notifyListeners();
    await load(silent: true);
  }

  Future<void> setTag(String tag) async {
    if (_tag == tag) return;
    _tag = tag;
    notifyListeners();
    await load(silent: true);
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
