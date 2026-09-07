import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/search_results.dart';
import '../../domain/usecases/search_all.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider({required SearchAll searchAll}) : _searchAll = searchAll;

  final SearchAll _searchAll;

  /// Debounce so typing does not fire a query per keystroke on a mobile
  /// connection.
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _timer;
  SearchResults _results = const SearchResults();
  String _query = '';
  String? _tag;
  TimeWindow _window = TimeWindow.all;
  bool _searching = false;
  Failure? _failure;

  SearchResults get results => _results;
  String get query => _query;
  String? get tag => _tag;
  TimeWindow get window => _window;
  bool get searching => _searching;
  Failure? get failure => _failure;
  bool get hasQuery => _query.trim().length >= 2;

  void onQueryChanged(String value) {
    _query = value;
    notifyListeners();

    _timer?.cancel();
    if (value.trim().length < 2) {
      _results = const SearchResults();
      notifyListeners();
      return;
    }
    _timer = Timer(_debounce, run);
  }

  void setTag(String? tag) {
    _tag = _tag == tag ? null : tag;
    notifyListeners();
    if (hasQuery) unawaited(run());
  }

  void setWindow(TimeWindow window) {
    _window = window;
    notifyListeners();
    if (hasQuery) unawaited(run());
  }

  Future<void> run() async {
    _searching = true;
    notifyListeners();

    final result = await _searchAll(
      SearchParams(text: _query, tag: _tag, window: _window),
    );
    result.fold(
      (failure) => _failure = failure,
      (results) {
        _results = results;
        _failure = null;
      },
    );

    _searching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
