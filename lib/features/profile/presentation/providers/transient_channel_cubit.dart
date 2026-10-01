import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mint/core/error/failures.dart';
import 'package:mint/features/feed/domain/entities/post.dart';
import 'package:mint/features/feed/domain/usecases/get_feed.dart';
import 'package:mint/features/profile/domain/entities/profile.dart';
import 'package:mint/features/profile/domain/usecases/get_profile.dart';
import 'package:mint/features/profile/domain/usecases/toggle_follow.dart';

class ChannelState extends Equatable {
  const ChannelState({
    this.profile,
    this.stats = const FollowStats(),
    this.posts = const [],
    this.isLoading = true,
    this.failure,
    this.followFailure,
  });

  final Profile? profile;
  final FollowStats stats;
  final List<Post> posts;
  final bool isLoading;

  /// Loading the channel failed (full-screen error).
  final Failure? failure;

  /// A follow / unfollow was rejected (snackbar, then cleared).
  final Failure? followFailure;

  ChannelState copyWith({
    Profile? profile,
    FollowStats? stats,
    List<Post>? posts,
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
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      followFailure:
          clearFollowFailure ? null : followFailure ?? this.followFailure,
    );
  }

  @override
  List<Object?> get props =>
      [profile, stats, posts, isLoading, failure, followFailure];
}

class ChannelCubit extends Cubit<ChannelState> {
  ChannelCubit({
    required GetProfileByUsername getProfileByUsername,
    required GetFollowStats getFollowStats,
    required GetPostsByAuthor getPostsByAuthor,
    required SetFollowing setFollowing,
  })  : _getProfileByUsername = getProfileByUsername,
        _getFollowStats = getFollowStats,
        _getPostsByAuthor = getPostsByAuthor,
        _setFollowing = setFollowing,
        super(const ChannelState());

  final GetProfileByUsername _getProfileByUsername;
  final GetFollowStats _getFollowStats;
  final GetPostsByAuthor _getPostsByAuthor;
  final SetFollowing _setFollowing;

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
    ]);
    if (isClosed) return;

    emit(state.copyWith(
      profile: profile,
      stats: results[0].valueOrNull as FollowStats? ?? const FollowStats(),
      posts: results[1].valueOrNull as List<Post>? ?? const [],
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
      (failure) => emit(state.copyWith(stats: previous, followFailure: failure)),
      (stats) => emit(state.copyWith(stats: stats)),
    );
  }

  void clearFollowFailure() => emit(state.copyWith(clearFollowFailure: true));
}
