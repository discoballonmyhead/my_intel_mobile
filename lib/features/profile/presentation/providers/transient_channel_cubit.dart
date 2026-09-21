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
  });

  final Profile? profile;
  final FollowStats stats;
  final List<Post> posts;
  final bool isLoading;
  final Failure? failure;

  ChannelState copyWith({
    Profile? profile,
    FollowStats? stats,
    List<Post>? posts,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ChannelState(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [profile, stats, posts, isLoading, failure];
}

class ChannelCubit extends Cubit<ChannelState> {
  ChannelCubit({
    required GetProfileByUsername getProfileByUsername,
    required GetFollowStats getFollowStats,
    required GetPostsByAuthor getPostsByAuthor,
    required ToggleFollow toggleFollow,
  })  : _getProfileByUsername = getProfileByUsername,
        _getFollowStats = getFollowStats,
        _getPostsByAuthor = getPostsByAuthor,
        _toggleFollow = toggleFollow,
        super(const ChannelState());

  final GetProfileByUsername _getProfileByUsername;
  final GetFollowStats _getFollowStats;
  final GetPostsByAuthor _getPostsByAuthor;
  final ToggleFollow _toggleFollow;

  Future<void> load(String username) async {
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final profileRes = await _getProfileByUsername(username);
    final profile = profileRes.valueOrNull;

    if (profile == null) {
      emit(state.copyWith(
        isLoading: false,
        failure: profileRes.failureOrNull,
      ));
      return;
    }

    final statsRes = await _getFollowStats(profile.id);
    final postsRes = await _getPostsByAuthor(profile.id);

    emit(state.copyWith(
      profile: profile,
      stats: statsRes.valueOrNull ?? const FollowStats(),
      posts: postsRes.valueOrNull ?? const [],
      isLoading: false,
    ));
  }

  Future<void> toggleFollow() async {
    final profileId = state.profile?.id;
    if (profileId == null) return;

    // Optimistic update
    final previousStats = state.stats;
    final optimisticStats = previousStats.copyWith(
      isFollowing: !previousStats.isFollowing,
      followers: previousStats.isFollowing
          ? (previousStats.followers - 1).clamp(0, 1 << 30)
          : previousStats.followers + 1,
    );

    emit(state.copyWith(stats: optimisticStats));

    // Actual API Call
    final result = await _toggleFollow(profileId);

    // Revert on failure or apply actual updated data on success
    emit(state.copyWith(stats: result.valueOrNull ?? previousStats));
  }
}
