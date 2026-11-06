import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/core/constants/user_role.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/core/utils/result.dart';
import 'package:mint/features/credibility/domain/entities/credibility_report.dart';
import 'package:mint/features/credibility/domain/usecases/get_credibility.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/feed/domain/post_updates.dart';
import 'package:mint/features/feed/domain/usecases/get_feed.dart';
import 'package:mint/features/feed/domain/usecases/toggle_interaction.dart';
import 'package:mint/features/profile/domain/entities/profile.dart';
import 'package:mint/features/profile/domain/usecases/get_profile.dart';
import 'package:mint/features/profile/domain/usecases/toggle_follow.dart';

class ChannelState extends Equatable {
  const ChannelState({
    this.profile,
    this.stats = const FollowStats(),
    this.posts = const [],
    this.credibility,
    this.isLoading = true,
    this.failure,
    this.followFailure,
  });

  final Profile? profile;
  final FollowStats stats;
  final List<Post> posts;

  /// Analysts only: score + breakdown, same as the web profile.
  final CredibilityReport? credibility;
  final bool isLoading;

  /// Loading the channel failed (full-screen error).
  final Failure? failure;

  /// A follow / unfollow was rejected (snackbar, then cleared).
  final Failure? followFailure;

  ChannelState copyWith({
    Profile? profile,
    FollowStats? stats,
    List<Post>? posts,
    CredibilityReport? credibility,
    bool? isLoading,
    Failure? failure,
    Failure? followFailure,
    bool clearFailure = false,
    bool clearFollowFailure = false,
  }) {
    return ChannelState(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      posts: posts ?? this.posts,
      credibility: credibility ?? this.credibility,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      followFailure:
          clearFollowFailure ? null : followFailure ?? this.followFailure,
    );
  }

  @override
  List<Object?> get props =>
      [profile, stats, posts, credibility, isLoading, failure, followFailure];
}

class ChannelCubit extends Cubit<ChannelState> {
  ChannelCubit({
    required GetProfileByUsername getProfileByUsername,
    required GetFollowStats getFollowStats,
    required GetPostsByAuthor getPostsByAuthor,
    required SetFollowing setFollowing,
    required GetCredibility getCredibility,
    ToggleLike? toggleLike,
    ToggleSave? toggleSave,
    ToggleRepost? toggleRepost,
    PostUpdates? postUpdates,
  })  : _getProfileByUsername = getProfileByUsername,
        _getFollowStats = getFollowStats,
        _getPostsByAuthor = getPostsByAuthor,
        _setFollowing = setFollowing,
        _getCredibility = getCredibility,
        _toggleLike = toggleLike,
        _toggleSave = toggleSave,
        _toggleRepost = toggleRepost,
        _postUpdates = postUpdates,
        super(const ChannelState()) {
    _updatesSub = postUpdates?.stream.listen(_replace);
  }

  final GetProfileByUsername _getProfileByUsername;
  final GetFollowStats _getFollowStats;
  final GetPostsByAuthor _getPostsByAuthor;
  final SetFollowing _setFollowing;
  final GetCredibility _getCredibility;
  final ToggleLike? _toggleLike;
  final ToggleSave? _toggleSave;
  final ToggleRepost? _toggleRepost;
  final PostUpdates? _postUpdates;
  StreamSubscription<Post>? _updatesSub;

  /// Bumped on every tap so only the latest response is applied.
  int _followToken = 0;

  Future<void> load(String username) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final profileRes = await _getProfileByUsername(username);
    if (isClosed) return;
    final profile = profileRes.valueOrNull;

    if (profile == null) {
      emit(state.copyWith(isLoading: false, failure: profileRes.failureOrNull));
      return;
    }

    final results = await Future.wait([
      _getFollowStats(profile.id),
      _getPostsByAuthor(profile.id),
      if (profile.role == UserRole.osint) _getCredibility(profile.id),
    ]);
    if (isClosed) return;

    final report = results.length > 2
        ? results[2].valueOrNull as CredibilityReport?
        : null;
    emit(state.copyWith(
      profile: report == null ? profile : profile.copyWith(score: report.score),
      stats: results[0].valueOrNull as FollowStats? ?? const FollowStats(),
      posts: results[1].valueOrNull as List<Post>? ?? const [],
      credibility: report,
      isLoading: false,
    ));
  }

  /// Optimistic. Sends the *desired* state (not "toggle"), so fast double
  /// taps settle on whatever the user tapped last.
  Future<void> toggleFollow() async {
    final profileId = state.profile?.id;
    if (profileId == null) return;

    final previous = state.stats;
    final follow = !previous.isFollowing;
    final token = ++_followToken;

    emit(state.copyWith(
      clearFollowFailure: true,
      stats: previous.copyWith(
        isFollowing: follow,
        followers: follow
            ? previous.followers + 1
            : (previous.followers - 1).clamp(0, 1 << 30),
      ),
    ));

    final result = await _setFollowing(
        SetFollowingParams(targetUserId: profileId, follow: follow));
    if (isClosed || token != _followToken) return;

    result.fold(
      (failure) =>
          emit(state.copyWith(stats: previous, followFailure: failure)),
      (stats) => emit(state.copyWith(stats: stats)),
    );
  }

  void clearFollowFailure() => emit(state.copyWith(clearFollowFailure: true));

  // ── Post actions (same use cases as the Feed and your own Profile) ──

  Future<void> toggleLike(Post post) => _optimistic(
        post.copyWith(
          liked: !post.liked,
          likes:
              post.liked ? (post.likes - 1).clamp(0, 1 << 30) : post.likes + 1,
        ),
        post,
        _toggleLike == null ? null : () => _toggleLike(post),
      );

  Future<void> toggleSave(Post post) => _optimistic(
        post.copyWith(saved: !post.saved),
        post,
        _toggleSave == null ? null : () => _toggleSave(post),
      );

  Future<void> toggleRepost(Post post, {String? quote}) => _optimistic(
        post.copyWith(
          reposted: !post.reposted,
          repostCount: post.reposted
              ? (post.repostCount - 1).clamp(0, 1 << 30)
              : post.repostCount + 1,
        ),
        post,
        _toggleRepost == null
            ? null
            : () => _toggleRepost(ToggleRepostParams(post: post, quote: quote)),
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
    if (updated != null) _postUpdates?.publish(updated);
  }

  /// Keeps this list in step with the Feed and other screens.
  void _replace(Post post) {
    if (isClosed || !state.posts.any((p) => p.id == post.id)) return;
    emit(state.copyWith(
        posts: [for (final p in state.posts) p.id == post.id ? post : p]));
  }

  @override
  Future<void> close() {
    _updatesSub?.cancel();
    return super.close();
  }
}
