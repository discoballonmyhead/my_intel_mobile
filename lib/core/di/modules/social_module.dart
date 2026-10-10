import 'package:get_it/get_it.dart';

import '../../../features/profile/domain/usecases/toggle_follow.dart';
import '../../../features/profile/presentation/cubits/follow_list_cubit.dart';

/// Follow / unfollow and follower lists. (ToggleFollow and GetFollowStats are
/// registered with the rest of the profile feature in `Injection.init`.)
void registerSocialModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => SetFollowing(sl()))
    ..registerLazySingleton(() => GetFollowList(sl()))
    // sl<FollowListCubit>(param1: FollowListArgs(...))
    ..registerFactoryParam<FollowListCubit, FollowListArgs, void>(
      (args, _) => FollowListCubit(
        args: args,
        getFollowList: sl(),
        setFollowing: sl(),
      ),
    );
}
