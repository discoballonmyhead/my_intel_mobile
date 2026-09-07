import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/get_feed.dart';
import '../../domain/usecases/toggle_interaction.dart';

enum FeedStatus { initial, loading, ready, error }

/// Drives the general feed. Interactions are applied optimistically and rolled
/// back if the write fails, so a tap feels instant on a phone connection.
class FeedProvider extends ChangeNotifier {
  FeedProvider({
    required GetFeed getFeed,
    required CreatePost createPost,
    required ToggleLike toggleLike,
    required ToggleSave toggleSave,
    required ToggleRepost toggleRepost,
    required WatchNewPosts watchNewPosts,
  })  : _getFeed = getFeed,
        _createPost = createPost,
        _toggleLike = toggleLike,
        _toggleSave = toggleSave,
        _toggleRepost = toggleRepost,
        _watchNewPosts = watchNewPosts;

  final GetFeed _getFeed;
  final CreatePost _createPost;
  final ToggleLike _toggleLike;
  final ToggleSave _toggleSave;
  final ToggleRepost _toggleRepost;
  final WatchNewPosts _watchNewPosts;

  StreamSubscription<Post>? _realtimeSub;

  List<FeedItem> _items = const [];
  FeedStatus _status = FeedStatus.initial;
  Failure? _failure;
  bool _posting = false;

  List<FeedItem> get items => _items;
  FeedStatus get status => _status;
  Failure? get failure => _failure;
  bool get posting => _posting;
  bool get isEmpty => _items.isEmpty && _status == FeedStatus.ready;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _status = FeedStatus.loading;
      notifyListeners();
    }

    final result = await _getFeed(const NoParams());
    result.fold(
      (failure) {
        _failure = failure;
        _status = FeedStatus.error;
      },
      (items) {
        _items = items;
        _failure = null;
        _status = FeedStatus.ready;
      },
    );
    notifyListeners();
  }

  Future<void> refresh() => load(silent: true);

  /// Subscribes to `content.posts` inserts. Safe to call more than once.
  void listenForNewPosts() {
    _realtimeSub ??= _watchNewPosts(const NoParams()).listen((post) {
      // Ignore anything already on screen (our own insert echoing back).
      if (_items.any((item) => item.post.id == post.id)) return;
      _items = [OriginalPost(post), ..._items];
      notifyListeners();
    });
  }

  Future<bool> createPost(CreatePostParams params) async {
    _posting = true;
    notifyListeners();

    final result = await _createPost(params);
    _posting = false;

    return result.fold(
      (failure) {
        _failure = failure;
        notifyListeners();
        return false;
      },
      (post) {
        if (!_items.any((item) => item.post.id == post.id)) {
          _items = [OriginalPost(post), ..._items];
        }
        _failure = null;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> toggleLike(Post post) => _optimistic(
        post,
        preview: post.copyWith(
          liked: !post.liked,
          likes: post.liked ? (post.likes - 1).clamp(0, 1 << 30) : post.likes + 1,
        ),
        action: () => _toggleLike(post),
      );

  Future<void> toggleSave(Post post) => _optimistic(
        post,
        preview: post.copyWith(saved: !post.saved),
        action: () => _toggleSave(post),
      );

  Future<void> toggleRepost(Post post, {String? quote}) => _optimistic(
        post,
        preview: post.copyWith(
          reposted: !post.reposted,
          repostCount: post.reposted
              ? (post.repostCount - 1).clamp(0, 1 << 30)
              : post.repostCount + 1,
        ),
        action: () => _toggleRepost(ToggleRepostParams(post: post, quote: quote)),
      );

  /// Swap in [preview] straight away, then reconcile with the server's answer.
  /// On failure the original post is restored and the failure surfaced.
  Future<void> _optimistic(
    Post original, {
    required Post preview,
    required Future<dynamic> Function() action,
  }) async {
    _replacePost(preview);
    notifyListeners();

    final result = await action();
    result.fold(
      (Failure failure) {
        _replacePost(original);
        _failure = failure;
        notifyListeners();
      },
      (Post updated) {
        _replacePost(updated);
        notifyListeners();
      },
    );
  }

  /// A post can appear twice — once as an original and once inside a repost
  /// card — so every occurrence is updated.
  void _replacePost(Post post) {
    _items = _items.map((item) {
      if (item.post.id != post.id) return item;
      return switch (item) {
        OriginalPost() => OriginalPost(post),
        RepostedPost(
          :final repostId,
          :final repostedAt,
          :final reposter,
          :final quote
        ) =>
          RepostedPost(
            post,
            repostId: repostId,
            repostedAt: repostedAt,
            reposter: reposter,
            quote: quote,
          ),
      };
    }).toList();
  }

  void clearError() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
