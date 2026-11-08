import 'dart:async';
import 'dart:developer' as dev;

import '../datasources/post_remote_data_source.dart';

/// Which feed posts were shown, sent in small batches. Used for the staff
/// metrics (like rate per ranking version). Failures are ignored: metrics
/// must never get in the way of reading.
class FeedImpressions {
  FeedImpressions(this._remote);

  final PostRemoteDataSource _remote;

  /// The ranking version that produced the current feed ('chrono' when the
  /// ranked feed wasn't available).
  String version = 'chrono';

  final Map<int, int> _queue = {};
  final Set<int> _sent = {};
  Timer? _timer;

  void shown(int postId, int position) {
    if (_sent.contains(postId) || _queue.containsKey(postId)) return;
    _queue[postId] = position;
    if (_queue.length >= 20) {
      unawaited(flush());
    } else {
      _timer ??= Timer(const Duration(seconds: 8), () => unawaited(flush()));
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_queue.isEmpty) return;
    final batch = Map<int, int>.of(_queue);
    _queue.clear();
    _sent.addAll(batch.keys);
    try {
      await _remote.logImpressions([
        for (final e in batch.entries) {'post_id': e.key, 'position': e.value},
      ], version);
    } catch (e) {
      dev.log('impressions not sent: $e', name: 'FeedImpressions');
    }
  }

  /// A new feed was loaded: the same post may be counted again later.
  void newFeed(String servedVersion) {
    unawaited(flush());
    version = servedVersion;
    _sent.clear();
  }

  /// Account changed.
  void reset() {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    _sent.clear();
    version = 'chrono';
  }
}
