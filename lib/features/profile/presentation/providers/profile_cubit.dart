import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/usecases/usecase.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/feed/domain/post_updates.dart';
import 'package:mint/features/feed/domain/usecases/get_feed.dart';
import 'package:mint/features/feed/domain/usecases/toggle_interaction.dart';
import 'package:mint/features/profile/domain/entities/profile.dart';
import 'package:mint/features/profile/domain/usecases/apply_for_osint.dart';
import 'package:mint/features/profile/domain/usecases/get_profile.dart';
import 'package:mint/features/profile/domain/usecases/toggle_follow.dart';
import 'package:mint/features/profile/domain/usecases/update_profile.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.profile,
    this.application,
    this.stats = const FollowStats(),
    this.posts = const [],
    this.savedPosts = const [],
    this.reposts = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.failure,
    this.loadedForUserId,
  });

  final Profile? profile;
  final OsintApplication? application;
  final FollowStats stats;
  final List<Post> posts;
  final List<Post> savedPosts;
  final List<RepostedPost> reposts;
  final bool isLoading;
  final bool isSubmitting;
  final Failure? failure;
  final String? loadedForUserId;

  /// Posts you wrote and posts you reposted, newest first.
  List<FeedItem> get activity => [
        ...posts.map(OriginalPost.new),
        ...reposts,
      ]..sort((a, b) => b.sortedAt.compareTo(a.sortedAt));

  bool get canPublishStories => profile?.role.canPublishStories ?? false;
  bool get isAdmin => profile?.role.isAdmin ?? false;

  ProfileState copyWith({
    Profile? profile,
    OsintApplication? application,
    FollowStats? stats,
    List<Post>? posts,
    List<Post>? savedPosts,
    List<RepostedPost>? reposts,
    bool? isLoading,
    bool? isSubmitting,
    Failure? failure,
    String? loadedForUserId,
    bool clearFailure = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      application: application ?? this.application,
      stats: stats ?? this.stats,
      posts: posts ?? this.posts,
      savedPosts: savedPosts ?? this.savedPosts,
      reposts: reposts ?? this.reposts,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : failure ?? this.failure,
      loadedForUserId: loadedForUserId ?? this.loadedForUserId,
    );
  }

  @override
  List<Object?> get props => [
        profile,
        application,
        stats,
        posts,
        savedPosts,
        reposts,
        isLoading,
        isSubmitting,
        failure,
        loadedForUserId,
      ];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required String? initialUserId, // 1. Add this
    required GetProfile getProfile,
    required UpdateProfile updateProfile,
    required ApplyForOsint applyForOsint,
    required GetMyApplication getMyApplication,
    required GetFollowStats getFollowStats,
    required GetPostsByAuthor getPostsByAuthor,
    required GetSavedPosts getSavedPosts,
    ToggleLike? toggleLike,
    ToggleSave? toggleSave,
    ToggleRepost? toggleRepost,
    GetRepostsByUser? getRepostsByUser,
    PostUpdates? postUpdates,
  })  : _getProfile = getProfile,
        _getRepostsByUser = getRepostsByUser,
        _postUpdates = postUpdates,
        _toggleLike = toggleLike,
        _toggleSave = toggleSave,
        _toggleRepost = toggleRepost,
        _updateProfile = updateProfile,
        _applyForOsint = applyForOsint,
        _getMyApplication = getMyApplication,
        _getFollowStats = getFollowStats,
        _getPostsByAuthor = getPostsByAuthor,
        _getSavedPosts = getSavedPosts,
        super(const ProfileState()) {
    _updatesSub = postUpdates?.stream.listen(_onPostUpdated);
    // 2. Trigger the initial load immediately on creation
    syncWithUser(initialUserId);
  }

  final GetProfile _getProfile;
  final UpdateProfile _updateProfile;
  final ApplyForOsint _applyForOsint;
  final GetMyApplication _getMyApplication;
  final GetFollowStats _getFollowStats;
  final GetPostsByAuthor _getPostsByAuthor;
  final GetSavedPosts _getSavedPosts;
  final ToggleLike? _toggleLike;
  final ToggleSave? _toggleSave;
  final ToggleRepost? _toggleRepost;
  final GetRepostsByUser? _getRepostsByUser;
  final PostUpdates? _postUpdates;
  StreamSubscription<Post>? _updatesSub;

  /// Called by the auth listener whenever the session changes. Passing null
  /// clears state on sign-out so no stale profile leaks into the next session.
  Future<void> syncWithUser(String? userId) async {
    if (userId == null) {
      emit(const ProfileState()); // Clears everything
      return;
    }
    if (userId == state.loadedForUserId && state.profile != null) return;

    emit(state.copyWith(loadedForUserId: userId));
    await load(userId);
  }

  Future<void> load(String userId) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _getProfile(userId);
    final profile = result.valueOrNull;
    if (profile == null) {
      emit(state.copyWith(isLoading: false, failure: result.failureOrNull));
      return;
    }

    // Secondary sections: a failure here leaves that section empty rather
    // than failing the whole page.
    final (stats, posts, saved, application, reposts) = await (
      _getFollowStats(userId),
      _getPostsByAuthor(userId),
      _getSavedPosts(const NoParams()),
      _getMyApplication(const NoParams()),
      _loadReposts(userId),
    ).wait;
    if (isClosed || state.loadedForUserId != userId) return;

    emit(state.copyWith(
      isLoading: false,
      profile: profile,
      stats: stats.valueOrNull ?? const FollowStats(),
      posts: posts.valueOrNull ?? const [],
      savedPosts: saved.valueOrNull ?? const [],
      reposts: reposts,
      application: application.valueOrNull,
    ));
  }

  /// Pull-to-refresh and retry.
  Future<void> refresh() async {
    final userId = state.loadedForUserId;
    if (userId != null) await load(userId);
  }

  Future<bool> updateUsername(String username) async {
    final id = state.profile?.id;
    if (id == null) return false;

    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _updateProfile(
      UpdateProfileParams(userId: id, username: username),
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, failure: failure));
        return false;
      },
      (profile) {
        emit(state.copyWith(isLoading: false, profile: profile));
        return true;
      },
    );
  }

  Future<void> loadApplication() async {
    final result = await _getMyApplication(const NoParams());
    emit(state.copyWith(application: result.valueOrNull));
  }

  Future<bool> applyForOsint(OsintApplicationParams params) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _applyForOsint(params);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      (_) async {
        emit(state.copyWith(isSubmitting: false));
        await loadApplication();
        return true;
      },
    );
  }

  // ── Post actions on the Profile's own lists (same use cases as the Feed) ──

  Future<void> toggleLike(Post post) => _optimistic(
        post.copyWith(
          liked: !post.liked,
          likes:
              post.liked ? (post.likes - 1).clamp(0, 1 << 30) : post.likes + 1,
        ),
        post,
        _toggleLike == null ? null : () => _toggleLike(post),
      );

  Future<void> toggleSave(Post post) async {
    await _optimistic(post.copyWith(saved: !post.saved), post,
        _toggleSave == null ? null : () => _toggleSave(post));
    // Saving from Posts adds it to Saved; unsaved posts leave Saved.
    final now = [...state.posts, ...state.savedPosts]
        .firstWhere((p) => p.id == post.id, orElse: () => post);
    final saved = now.saved
        ? [
            if (!state.savedPosts.any((p) => p.id == now.id)) now,
            ...state.savedPosts
          ]
        : state.savedPosts.where((p) => p.id != now.id).toList();
    if (!isClosed) emit(state.copyWith(savedPosts: saved));
  }

  Future<void> toggleRepost(Post post) => _optimistic(
        post.copyWith(
          reposted: !post.reposted,
          repostCount: post.reposted
              ? (post.repostCount - 1).clamp(0, 1 << 30)
              : post.repostCount + 1,
        ),
        post,
        _toggleRepost == null
            ? null
            : () => _toggleRepost(ToggleRepostParams(post: post)),
      );

  /// Shows [preview] straight away, then the server's answer; restores
  /// [original] if the action fails.
  Future<void> _optimistic(Post preview, Post original,
      Future<Result<Post>> Function()? action) async {
    if (action == null) return;
    _replace(preview);
    final result = await action();
    if (isClosed) return;
    final updated = result.valueOrNull;
    _replace(updated ?? original);
    if (updated != null) {
      _postUpdates?.publish(updated);
      if (updated.reposted != original.reposted) await _refreshReposts();
    }
  }

  Future<List<RepostedPost>> _loadReposts(String userId) async =>
      (await _getRepostsByUser?.call(userId))?.valueOrNull ?? const [];

  Future<void> _refreshReposts() async {
    final userId = state.profile?.id;
    if (userId == null) return;
    final reposts = await _loadReposts(userId);
    if (!isClosed) emit(state.copyWith(reposts: reposts));
  }

  void _replace(Post post) {
    List<Post> swap(List<Post> list) =>
        [for (final p in list) p.id == post.id ? post : p];
    emit(state.copyWith(
      posts: swap(state.posts),
      savedPosts: swap(state.savedPosts),
      reposts: [
        for (final r in state.reposts)
          r.post.id == post.id
              ? RepostedPost(post,
                  repostId: r.repostId,
                  repostedAt: r.repostedAt,
                  reposter: r.reposter,
                  quote: r.quote)
              : r,
      ],
    ));
  }

  /// A post changed in the Feed (or was just created there): bring the
  /// Profile's lists in line without a refresh.
  void _onPostUpdated(Post post) {
    final me = state.profile?.id;
    if (me == null || isClosed) return;
    final known = [
      ...state.posts,
      ...state.savedPosts,
      ...state.reposts.map((r) => r.post)
    ].where((p) => p.id == post.id).firstOrNull;
    _replace(post);

    // A new post of yours shows at the top of Posts.
    if (known == null && post.author?.id == me) {
      emit(state.copyWith(posts: [post, ...state.posts]));
    }
    // Saved follows the bookmark.
    final inSaved = state.savedPosts.any((p) => p.id == post.id);
    if (post.saved && !inSaved) {
      emit(state.copyWith(savedPosts: [post, ...state.savedPosts]));
    } else if (!post.saved && inSaved) {
      emit(state.copyWith(
          savedPosts: state.savedPosts.where((p) => p.id != post.id).toList()));
    }
    // Reposting or undoing a repost changes what Posts lists.
    if (known == null || known.reposted != post.reposted)
      unawaited(_refreshReposts());
  }

  @override
  Future<void> close() {
    _updatesSub?.cancel();
    return super.close();
  }
}
