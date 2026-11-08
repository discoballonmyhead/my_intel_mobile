import 'package:get_it/get_it.dart';

import '../../../features/auth/presentation/providers/auth_cubit.dart';
import '../../../features/feed/presentation/providers/feed_provider.dart';
import '../../../features/lean/data/lean_repository.dart';
import '../../../features/lean/presentation/cubits/lean_cubit.dart';

/// The leaning compass (private to each user) and its feed filter.
void registerLeanModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => LeanRepository(sl()))
    ..registerLazySingleton<LeanCubit>(() => LeanCubit(
          sl(),
          // the feed is ranked on the server with the new filter
          onFilterChanged: () => sl<FeedProvider>().refresh(),
          currentUserId: () => sl<AuthCubit>().state.user?.id,
        ));
}
