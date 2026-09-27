import 'package:get_it/get_it.dart';

import '../../../features/feed/domain/usecases/manage_post.dart';
import '../../../features/feed/presentation/cubits/post_edit_history_cubit.dart';

/// Post edit / delete / history. The data source and repository are the
/// existing feed ones; FeedProvider receives EditPost and DeletePost.
void registerPostsModule(GetIt sl) {
  sl
    ..registerLazySingleton(() => EditPost(sl()))
    ..registerLazySingleton(() => DeletePost(sl()))
    ..registerLazySingleton(() => GetPostEditHistory(sl()))
    // sl<PostEditHistoryCubit>(param1: postId)
    ..registerFactoryParam<PostEditHistoryCubit, int, void>(
      (postId, _) => PostEditHistoryCubit(postId: postId, getHistory: sl()),
    );
}
