import 'package:get_it/get_it.dart';

import '../../../features/auth/presentation/providers/auth_cubit.dart';
import '../../../features/comments/data/datasources/comment_remote_data_source.dart';
import '../../../features/comments/data/repositories/comment_repository_impl.dart';
import '../../../features/comments/domain/repositories/comment_repository.dart';
import '../../../features/comments/domain/usecases/comment_usecases.dart';
import '../../../features/comments/presentation/cubits/post_detail_cubit.dart';

/// Comments & replies + the post detail screen.
void registerCommentsModule(GetIt sl) {
  sl
    ..registerLazySingleton<CommentRemoteDataSource>(
        () => CommentRemoteDataSourceImpl(sl()))
    ..registerLazySingleton<CommentRepository>(
        () => CommentRepositoryImpl(sl(), sl()))
    ..registerLazySingleton(() => GetComments(sl()))
    ..registerLazySingleton(() => GetReplies(sl()))
    ..registerLazySingleton(() => CreateComment(sl()))
    ..registerLazySingleton(() => EditComment(sl()))
    ..registerLazySingleton(() => DeleteComment(sl()))
    ..registerLazySingleton(() => ToggleCommentLike(sl()))
    ..registerLazySingleton(() => WatchPostComments(sl()))
    // sl<PostDetailCubit>(param1: postId)
    ..registerFactoryParam<PostDetailCubit, int, void>(
      (postId, _) => PostDetailCubit(
        postId: postId,
        myUserId: sl<AuthCubit>().state.user?.id,
        getPost: sl(),
        toggleLike: sl(),
        toggleSave: sl(),
        toggleRepost: sl(),
        getComments: sl(),
        getReplies: sl(),
        createComment: sl(),
        editComment: sl(),
        deleteComment: sl(),
        toggleCommentLike: sl(),
        watchComments: sl(),
      ),
    );
}
