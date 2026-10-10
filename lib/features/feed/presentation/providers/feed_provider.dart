import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/post.dart';
import '../../domain/post_updates.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/get_feed.dart';
import '../../domain/usecases/manage_post.dart';
import '../../domain/usecases/toggle_interaction.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../../profile/domain/usecases/toggle_follow.dart';

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
    required EditPost editPost,
    required DeletePost deletePost,
    required GetFollowedUserIds getFollowedUserIds,
    PostUpdates? postUpdates,
  })  : _getFeed = getFeed,
        _postUpdates = postUpdates,
        _getFollowedUserIds = getFollowedUserIds,
        _editPost = editPost,
        _deletePost = deletePost,
        _createPost = createPost,
        _toggleLike = toggleLike,
        _toggleSave = toggleSave,
        _toggleRepost = toggleRepost,
        _watchNewPosts = watchNewPosts {
    _listenForUpdates();
  }

  final GetFeed _getFeed;
  final CreatePost _createPost;
  final ToggleLike _toggleLike;
  final ToggleSave _toggleSave;
  final ToggleRepost _toggleRepost;
  final WatchNewPosts _watchNewPosts;
  final EditPost _editPost;
  final DeletePost _deletePost;
  final GetFollowedUserIds _getFollowedUserIds;

  StreamSubscription<Post>? _realtimeSub;
  final PostUpdates? _postUpdates;
  StreamSubscription<Post>? _updatesSub;

  /// Applies changes made elsewhere (the Profile) to posts in the Feed.
  void _listenForUpdates() {
    _updatesSub ??= _postUpdates?.stream.listen((post) {
      if (!_items.any((item) => item.post.id == post.id)) return;
      _replacePost(post);
      notifyListeners();
    });
  }

  List<FeedItem> _items = const [];
  FeedStatus _status = FeedStatus.initial;
  Failure? _failure;
  bool _posting = false;

  /// Posts that arrived over realtime while the user was reading. They wait
  /// behind the "new posts" pill instead of shoving the list around.
  List<Post> _pending = const [];

  /// Ids just revealed from [_pending], briefly highlighted in the list.
  Set<int> _freshIds = const {};
  Timer? _freshTimer;

  Set<String> _followedIds = const {};

  /// Bumped on every account change so a load started for the previous user
  /// can't land after the reset.
  int _session = 0;

  List<FeedItem> get items => _items;
  FeedStatus get status => _status;
  Failure? get failure => _failure;
  bool get posting => _posting;
  bool get isEmpty => _items.isEmpty && _status == FeedStatus.ready;
  int get pendingCount => _pending.length;
  List<String> get pendingAuthors => _pending
      .map((p) => p.author?.username)
      .whereType<String>()
      .toSet()
      .take(2)
      .toList();
  Set<int> get freshIds => _freshIds;
  Set<String> get followedIds => _followedIds;

  Future<void> load({bool silent = false}) async {
    final session = _session;
    if (!silent) {
      _status = FeedStatus.loading;
      notifyListeners();
    }

    final (result, followed) =
        await (_getFeed(const NoParams()), _getFollowedUserIds(const NoParams())).wait;
    if (session != _session) return;
    _followedIds = (followed.valueOrNull ?? const []).toSet();
    _pending = const [];
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

  /// Called when the signed-in account changes. Liked / saved / reposted
  /// flags are per user, so the old feed must never be shown to the next one.
  Future<void> syncWithUser(String? userId) async {
    final wasLoaded = _status != FeedStatus.initial;
    _session++;
    _items = const [];
    _pending = const [];
    _freshIds = const {};
    _followedIds = const {};
    _failure = null;
    _posting = false;
    _status = FeedStatus.initial;
    notifyListeners();
    if (userId != null && wasLoaded) await load();
  }

  /// Subscribes to `content.posts` inserts. Safe to call more than once.
  void listenForNewPosts() {
    _realtimeSub ??= _watchNewPosts(const NoParams()).listen((post) {
      // Ignore anything already on screen (our own insert echoing back).
      if (_items.any((item) => item.post.id == post.id)) return;
      if (_pending.any((p) => p.id == post.id)) return;
      _pending = [post, ..._pending];
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
        _pending = _pending.where((p) => p.id != post.id).toList();
        _failure = null;
        notifyListeners();
        _postUpdates?.publish(post);
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

  /// Reposts (optionally with a comment) or undoes a repost. With [me], your
  /// repost shows at the top of the Feed straight away, and undo removes it.
  Future<void> toggleRepost(Post post, {String? quote, Profile? me}) async {
    await _optimistic(
      post,
      preview: post.copyWith(
        reposted: !post.reposted,
        repostCount: post.reposted
            ? (post.repostCount - 1).clamp(0, 1 << 30)
            : post.repostCount + 1,
      ),
      action: () => _toggleRepost(ToggleRepostParams(post: post, quote: quote)),
    );
    if (me == null) return;
    final now = _items.where((i) => i.post.id == post.id).firstOrNull?.post;
    if (now == null || now.reposted == post.reposted) return; // failed
    if (now.reposted) {
      // The Feed hides reposts of your own posts; the original already shows.
      if (post.author?.id == me.id) return;
      _items = [
        RepostedPost(now,
            repostId: -now.id,
            repostedAt: DateTime.now().toUtc(),
            reposter: me,
            quote: quote),
        ..._items,
      ];
    } else {
      _items = _items
          .where((i) => !(i is RepostedPost &&
              i.post.id == post.id &&
              i.reposter?.id == me.id))
          .toList();
    }
    notifyListeners();
  }

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
        _postUpdates?.publish(updated);
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

  /// Saves an edit by the author. Returns false with [failure] set on error.
  Future<bool> editPost(Post post, String body) async {
    final result = await _editPost(EditPostParams(post: post, body: body));
    return result.fold(
      (failure) {
        _failure = failure;
        notifyListeners();
        return false;
      },
      (updated) {
        _replacePost(updated);
        notifyListeners();
        return true;
      },
    );
  }

  /// Author delete. Optimistic: the post disappears immediately and comes
  /// back if the server refuses.
  Future<bool> deletePost(Post post) async {
    final previous = _items;
    removeLocally(post.id);

    final result = await _deletePost(post.id);
    final failure = result.failureOrNull;
    if (failure != null) {
      _items = previous;
      _failure = failure;
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Pushes a post changed elsewhere (e.g. liked or commented on in the post
  /// detail screen) into the feed so both stay in step.
  void syncPost(Post post) {
    if (!_items.any((item) => item.post.id == post.id)) return;
    _replacePost(post);
    notifyListeners();
  }

  /// Drops every card showing [postId] (original and reposts). Also used after
  /// a moderator removes a post from the report screen.
  /// Moves the waiting posts to the top of the list and highlights them.
  void revealPending() {
    if (_pending.isEmpty) return;
    final fresh = _pending.where((p) => !_items.any((i) => i.post.id == p.id));
    _items = [...fresh.map(OriginalPost.new), ..._items];
    _freshIds = _pending.map((p) => p.id).toSet();
    _pending = const [];
    _freshTimer?.cancel();
    _freshTimer = Timer(const Duration(seconds: 3), () {
      _freshIds = const {};
      notifyListeners();
    });
    notifyListeners();
  }

  void removeLocally(int postId) {
    final next = _items.where((item) => item.post.id != postId).toList();
    if (next.length == _items.length) return;
    _items = next;
    notifyListeners();
  }

  void clearError() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _updatesSub?.cancel();
    _freshTimer?.cancel();
    super.dispose();
  }
}
