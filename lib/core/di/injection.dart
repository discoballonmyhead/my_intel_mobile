import 'package:get_it/get_it.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';
import 'package:mint/features/profile/presentation/providers/transient_channel_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/reset_password.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/watch_auth_state.dart';
import '../../features/auth/presentation/providers/auth_cubit.dart';
import '../../features/feed/data/datasources/post_remote_data_source.dart';
import '../../features/feed/data/repositories/post_repository_impl.dart';
import '../../features/feed/domain/repositories/post_repository.dart';
import '../../features/feed/domain/usecases/create_post.dart';
import '../../features/feed/domain/usecases/get_feed.dart';
import '../../features/feed/domain/usecases/toggle_interaction.dart';
import '../../features/feed/presentation/providers/feed_provider.dart';
import '../../features/media/data/datasources/media_remote_data_source.dart';
import '../../features/media/data/repositories/media_repository_impl.dart';
import '../../features/media/domain/repositories/media_repository.dart';
import '../../features/media/domain/usecases/media_usecases.dart';
import '../../features/media/presentation/providers/media_provider.dart';
import '../../features/moderation/data/datasources/moderation_remote_data_source.dart';
import '../../features/moderation/data/repositories/moderation_repository_impl.dart';
import '../../features/moderation/domain/repositories/moderation_repository.dart';
import '../../features/moderation/domain/usecases/moderation_usecases.dart';
import '../../features/moderation/presentation/providers/moderation_provider.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/apply_for_osint.dart';
import '../../features/profile/domain/usecases/get_profile.dart';
import '../../features/profile/domain/usecases/toggle_follow.dart';
import '../../features/profile/domain/usecases/update_profile.dart';
import '../../features/search/data/datasources/search_remote_data_source.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/search/domain/usecases/search_all.dart';
import '../../features/search/presentation/providers/search_provider.dart';
import '../../features/stories/data/datasources/story_remote_data_source.dart';
import '../../features/stories/data/repositories/story_repository_impl.dart';
import '../../features/stories/domain/repositories/story_repository.dart';
import '../../features/stories/domain/services/trending_ranker.dart';
import '../../features/stories/domain/usecases/get_stories.dart';
import '../../features/stories/domain/usecases/get_trending_stories.dart';
import '../../features/stories/domain/usecases/publish_intel.dart';
import '../../features/stories/presentation/providers/story_provider.dart';
import '../network/supabase_service.dart';
import '../responsive/responsive_provider.dart';
import '../theme/theme_provider.dart';
import 'modules/account_module.dart';
import 'modules/auth_extras_module.dart';
import 'modules/comments_module.dart';
import 'modules/social_module.dart';
import 'modules/admin_module.dart';
import 'modules/messaging_module.dart';
import 'modules/posts_module.dart';
import 'modules/reports_module.dart';

final sl = GetIt.instance; // sl stands for Service Locator

class Injection {
  const Injection._();

  static Future<void> init({
    SupabaseClient? client,
    ThemeStore? themeStore,
  }) async {
    // ── Infrastructure ──
    sl.registerLazySingleton<SupabaseService>(
      () => SupabaseService(client ?? Supabase.instance.client),
    );
    sl.registerLazySingleton<ThemeProvider>(
      () => ThemeProvider(themeStore ?? InMemoryThemeStore())..load(),
    );
    sl.registerLazySingleton<ResponsiveProvider>(() => ResponsiveProvider());

    // ── Data Sources ──
    sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<ProfileRemoteDataSource>(
        () => ProfileRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<PostRemoteDataSource>(
        () => PostRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<StoryRemoteDataSource>(
        () => StoryRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<MediaRemoteDataSource>(
        () => MediaRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<ModerationRemoteDataSource>(
        () => ModerationRemoteDataSourceImpl(sl()));
    sl.registerLazySingleton<SearchRemoteDataSource>(
        () => SearchRemoteDataSourceImpl(sl()));

    // ── Repositories ──
    sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
    sl.registerLazySingleton<ProfileRepository>(
        () => ProfileRepositoryImpl(sl()));
    sl.registerLazySingleton<PostRepository>(
        () => PostRepositoryImpl(sl(), sl(), sl()));
    sl.registerLazySingleton<StoryRepository>(
        () => StoryRepositoryImpl(sl(), sl(), sl(), sl()));
    sl.registerLazySingleton<MediaRepository>(
        () => MediaRepositoryImpl(sl(), sl(), sl()));
    sl.registerLazySingleton<ModerationRepository>(
        () => ModerationRepositoryImpl(sl(), sl(), sl()));
    sl.registerLazySingleton<SearchRepository>(
        () => SearchRepositoryImpl(sl(), sl()));

    // ── Domain Services ──
    sl.registerLazySingleton<TrendingRanker>(() => const TrendingRanker());

    // ── Use Cases ──
    // Auth
    sl.registerLazySingleton(() => SignIn(sl()));
    sl.registerLazySingleton(() => SignUp(sl()));
    sl.registerLazySingleton(() => SignOut(sl()));
    sl.registerLazySingleton(() => SendPasswordReset(sl()));
    sl.registerLazySingleton(() => UpdatePassword(sl()));
    sl.registerLazySingleton(() => ResendVerification(sl()));
    sl.registerLazySingleton(() => WatchAuthState(sl()));
    // Profile
    sl.registerLazySingleton(() => GetProfile(sl()));
    sl.registerLazySingleton(() => GetProfileByUsername(sl()));
    sl.registerLazySingleton(() => UpdateProfile(sl()));
    sl.registerLazySingleton(() => ToggleFollow(sl()));
    sl.registerLazySingleton(() => GetFollowStats(sl()));
    sl.registerLazySingleton(() => ApplyForOsint(sl()));
    sl.registerLazySingleton(() => GetMyApplication(sl()));
    // Feed
    sl.registerLazySingleton(() => GetFeed(sl()));
    sl.registerLazySingleton(() => GetSavedPosts(sl()));
    sl.registerLazySingleton(() => GetPostsByAuthor(sl()));
    sl.registerLazySingleton(() => WatchNewPosts(sl()));
    sl.registerLazySingleton(() => CreatePost(sl()));
    sl.registerLazySingleton(() => ToggleLike(sl()));
    sl.registerLazySingleton(() => ToggleSave(sl()));
    sl.registerLazySingleton(() => ToggleRepost(sl()));
    // Stories
    sl.registerLazySingleton(() => GetStories(sl()));
    sl.registerLazySingleton(() => GetStory(sl()));
    sl.registerLazySingleton(() => SearchStories(sl()));
    sl.registerLazySingleton(() => GetRegionActivity(sl()));
    sl.registerLazySingleton(() => GetTrendingStories(sl(), sl()));
    sl.registerLazySingleton(() => PublishIntel(sl()));
    // Media
    sl.registerLazySingleton(() => GetVideos(sl()));
    sl.registerLazySingleton(() => ToggleVideoLike(sl()));
    sl.registerLazySingleton(() => GetActiveStreams(sl()));
    sl.registerLazySingleton(() => CreateStream(sl()));
    sl.registerLazySingleton(() => SetStreamStatus(sl()));
    // Moderation
    sl.registerLazySingleton(() => GetPostModeration(sl()));
    sl.registerLazySingleton(() => SubmitNote(sl()));
    sl.registerLazySingleton(() => GetOpenClaims(sl()));
    sl.registerLazySingleton(() => ResolveClaim(sl()));
    sl.registerLazySingleton(() => SubmitFeedback(sl()));
    // Search
    sl.registerLazySingleton(() => SearchAll(sl()));
    sl.registerLazySingleton<AuthCubit>(() => AuthCubit(
          repository: sl(),
          signIn: sl(),
          signUp: sl(),
          signOut: sl(),
          sendPasswordReset: sl(),
          updatePassword: sl(),
          resendVerification: sl(),
        ));

    sl.registerLazySingleton<ProfileCubit>(() => ProfileCubit(
          // Pass the initial ID right when the Cubit is created
          initialUserId: sl<AuthCubit>().state.user?.id,
          getProfile: sl(),
          updateProfile: sl(),
          applyForOsint: sl(),
          getMyApplication: sl(),
        ));
    sl.registerLazySingleton<FeedProvider>(() => FeedProvider(
          getFeed: sl(),
          createPost: sl(),
          toggleLike: sl(),
          toggleSave: sl(),
          toggleRepost: sl(),
          watchNewPosts: sl(),
          editPost: sl(),
          deletePost: sl(),
        ));
    sl.registerLazySingleton<StoryProvider>(() => StoryProvider(
          getStories: sl(),
          getTrending: sl(),
          publishIntel: sl(),
        ));

    sl.registerLazySingleton<MediaProvider>(() => MediaProvider(
          getVideos: sl(),
          toggleVideoLike: sl(),
          getActiveStreams: sl(),
          createStream: sl(),
          setStreamStatus: sl(),
        ));

    sl.registerLazySingleton<ModerationProvider>(() => ModerationProvider(
          getPostModeration: sl(),
          submitNote: sl(),
          getOpenClaims: sl(),
          resolveClaim: sl(),
          submitFeedback: sl(),
        ));

    sl.registerLazySingleton<SearchProvider>(
        () => SearchProvider(searchAll: sl()));

    // ── Transient Presentation State (Factories) ──
    // Factories return a NEW instance every time they are called.
    // Perfect for route-specific state like ChannelCubit!
    sl.registerFactory<ChannelCubit>(() => ChannelCubit(
          getProfileByUsername: sl(),
          getFollowStats: sl(),
          getPostsByAuthor: sl(),
          setFollowing: sl(),
        ));

    // ── New feature modules ──
    registerAuthExtrasModule(sl);
    registerSocialModule(sl);
    registerCommentsModule(sl);
    registerAccountModule(sl);
    registerPostsModule(sl);
    registerMessagingModule(sl);
    registerReportsModule(sl);
    registerAdminModule(sl);
  }
}
