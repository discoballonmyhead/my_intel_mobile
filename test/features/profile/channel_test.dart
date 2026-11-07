import 'package:flutter_test/flutter_test.dart';
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
import 'package:mint/features/profile/presentation/pages/channel_page.dart';
import 'package:mint/features/profile/presentation/providers/transient_channel_cubit.dart';

const _shresth = Profile(id: 'u1', username: 'shresth', role: UserRole.osint);
final _post =
    Post(id: 7, body: 'Water is knee-deep', createdAt: DateTime(2026));

class _Profile implements GetProfileByUsername {
  _Profile(this.result);
  final Result<Profile> result;
  @override
  Future<Result<Profile>> call(String username) async => result;
}

class _Stats implements GetFollowStats {
  @override
  Future<Result<FollowStats>> call(String id) async =>
      const Ok(FollowStats(followers: 128, following: 64, followsYou: true));
}

class _Posts implements GetPostsByAuthor {
  @override
  Future<Result<List<Post>>> call(String id) async => Ok([_post]);
}

class _Follow implements SetFollowing {
  _Follow({this.fail = false});
  final bool fail;
  @override
  Future<Result<FollowStats>> call(SetFollowingParams p) async => fail
      ? const Err(NetworkFailure('No internet connection.'))
      : Ok(FollowStats(
          followers: p.follow ? 129 : 128,
          following: 64,
          isFollowing: p.follow,
          followsYou: true));
}

class _Cred implements GetCredibility {
  @override
  Future<Result<CredibilityReport?>> call(String id) async => const Ok(null);
}

class _Like implements ToggleLike {
  _Like({this.fail = false});
  final bool fail;
  @override
  Future<Result<Post>> call(Post p) async => fail
      ? const Err(NetworkFailure('No internet connection.'))
      : Ok(p.copyWith(liked: !p.liked, likes: p.liked ? 0 : 1));
}

ChannelCubit _cubit({
  Result<Profile> profile = const Ok(_shresth),
  bool followFails = false,
  bool likeFails = false,
  PostUpdates? updates,
}) =>
    ChannelCubit(
      getProfileByUsername: _Profile(profile),
      getFollowStats: _Stats(),
      getPostsByAuthor: _Posts(),
      setFollowing: _Follow(fail: followFails),
      getCredibility: _Cred(),
      toggleLike: _Like(fail: likeFails),
      postUpdates: updates,
    );

void main() {
  test('the line under the name shows the role and Follows you', () {
    expect(channelSubtitle(_shresth, followsYou: true),
        'OSINT analyst  ·  Follows you');
    expect(channelSubtitle(_shresth, followsYou: false), 'OSINT analyst');
  });

  test('loads the profile, numbers and posts', () async {
    final cubit = _cubit();
    await cubit.load('shresth');
    expect(cubit.state.profile, _shresth);
    expect(cubit.state.stats.followers, 128);
    expect(cubit.state.stats.followsYou, isTrue);
    expect(cubit.state.posts.single.id, 7);
  });

  test('a missing username is a not-found failure, not a network one',
      () async {
    final cubit =
        _cubit(profile: const Err(NotFoundFailure('No such channel.')));
    await cubit.load('ghost');
    expect(cubit.state.profile, isNull);
    expect(cubit.state.failure, isA<NotFoundFailure>());
  });

  test('Follow shows Following straight away and keeps it', () async {
    final cubit = _cubit();
    await cubit.load('shresth');
    final pending = cubit.toggleFollow();
    expect(cubit.state.stats.isFollowing, isTrue);
    expect(cubit.state.stats.followers, 129);
    await pending;
    expect(cubit.state.stats.isFollowing, isTrue);
  });

  test('a failed Follow goes back and reports it', () async {
    final cubit = _cubit(followFails: true);
    await cubit.load('shresth');
    await cubit.toggleFollow();
    expect(cubit.state.stats.isFollowing, isFalse);
    expect(cubit.state.stats.followers, 128);
    expect(cubit.state.followFailure, isA<NetworkFailure>());
  });

  test('liking a post updates it and tells the Feed', () async {
    final updates = PostUpdates();
    final sent = <Post>[];
    updates.stream.listen(sent.add);
    final cubit = _cubit(updates: updates);
    await cubit.load('shresth');
    await cubit.toggleLike(cubit.state.posts.single);
    expect(cubit.state.posts.single.liked, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(sent.single.liked, isTrue);
  });

  test('a failed like goes back', () async {
    final cubit = _cubit(likeFails: true);
    await cubit.load('shresth');
    await cubit.toggleLike(cubit.state.posts.single);
    expect(cubit.state.posts.single.liked, isFalse);
  });

  test('a post changed elsewhere updates here too', () async {
    final updates = PostUpdates();
    final cubit = _cubit(updates: updates);
    await cubit.load('shresth');
    updates.publish(_post.copyWith(saved: true));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.posts.single.saved, isTrue);
  });
}
