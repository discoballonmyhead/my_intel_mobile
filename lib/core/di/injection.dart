import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/reset_password.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/watch_auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
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
import '../../features/profile/presentation/providers/profile_provider.dart';
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

/// Composition root.
///
/// Wiring is done by hand with `provider` rather than a service locator: the
/// graph is visible in one file, nothing is resolved from a global registry,
/// and every dependency is passed through a constructor. Layers only ever
/// point inwards — data sources know Supabase, repositories know data sources,
/// use cases know repository *interfaces*, and presentation knows use cases.
class Injection {
  const Injection._();

  static List<SingleChildWidget> providers({
    SupabaseClient? client,
    ThemeStore? themeStore,
  }) {
    final service = SupabaseService(client ?? Supabase.instance.client);

    // ── Data sources ──
    final authRemote = AuthRemoteDataSourceImpl(service);
    final profileRemote = ProfileRemoteDataSourceImpl(service);
    final postRemote = PostRemoteDataSourceImpl(service);
    final storyRemote = StoryRemoteDataSourceImpl(service);
    final mediaRemote = MediaRemoteDataSourceImpl(service);
    final moderationRemote = ModerationRemoteDataSourceImpl(service);
    final searchRemote = SearchRemoteDataSourceImpl(service);

    // ── Repositories ──
    final AuthRepository authRepo = AuthRepositoryImpl(authRemote);
    final ProfileRepository profileRepo = ProfileRepositoryImpl(profileRemote);
    final PostRepository postRepo =
        PostRepositoryImpl(postRemote, profileRemote, service);
    final StoryRepository storyRepo =
        StoryRepositoryImpl(storyRemote, postRemote, profileRemote, service);
    final MediaRepository mediaRepo =
        MediaRepositoryImpl(mediaRemote, profileRemote, service);
    final ModerationRepository moderationRepo =
        ModerationRepositoryImpl(moderationRemote, profileRemote, service);
    final SearchRepository searchRepo =
        SearchRepositoryImpl(searchRemote, profileRemote);

    // Pure domain service, no dependencies of its own — the trending use case
    // composes it so the ordering rule lives outside both the repository and
    // the widgets.
    const ranker = TrendingRanker();

    return [
      // ── Infrastructure ──
      Provider<SupabaseService>.value(value: service),
      ChangeNotifierProvider(
        create: (_) =>
            ThemeProvider(themeStore ?? InMemoryThemeStore())..load(),
      ),
      ChangeNotifierProvider(create: (_) => ResponsiveProvider()),

      // ── Repositories, exposed for anything that needs one directly ──
      Provider<AuthRepository>.value(value: authRepo),
      Provider<ProfileRepository>.value(value: profileRepo),
      Provider<PostRepository>.value(value: postRepo),
      Provider<StoryRepository>.value(value: storyRepo),
      Provider<MediaRepository>.value(value: mediaRepo),
      Provider<ModerationRepository>.value(value: moderationRepo),
      Provider<SearchRepository>.value(value: searchRepo),

      // ── Domain services ──
      Provider<TrendingRanker>.value(value: ranker),

      // ── Use cases ──
      // Auth
      Provider(create: (_) => SignIn(authRepo)),
      Provider(create: (_) => SignUp(authRepo)),
      Provider(create: (_) => SignOut(authRepo)),
      Provider(create: (_) => SendPasswordReset(authRepo)),
      Provider(create: (_) => UpdatePassword(authRepo)),
      Provider(create: (_) => ResendVerification(authRepo)),
      Provider(create: (_) => WatchAuthState(authRepo)),
      // Profile
      Provider(create: (_) => GetProfile(profileRepo)),
      Provider(create: (_) => GetProfileByUsername(profileRepo)),
      Provider(create: (_) => UpdateProfile(profileRepo)),
      Provider(create: (_) => ToggleFollow(profileRepo)),
      Provider(create: (_) => GetFollowStats(profileRepo)),
      Provider(create: (_) => ApplyForOsint(profileRepo)),
      Provider(create: (_) => GetMyApplication(profileRepo)),
      // Feed
      Provider(create: (_) => GetFeed(postRepo)),
      Provider(create: (_) => GetSavedPosts(postRepo)),
      Provider(create: (_) => GetPostsByAuthor(postRepo)),
      Provider(create: (_) => WatchNewPosts(postRepo)),
      Provider(create: (_) => CreatePost(postRepo)),
      Provider(create: (_) => ToggleLike(postRepo)),
      Provider(create: (_) => ToggleSave(postRepo)),
      Provider(create: (_) => ToggleRepost(postRepo)),
      // Stories
      Provider(create: (_) => GetStories(storyRepo)),
      Provider(create: (_) => GetStory(storyRepo)),
      Provider(create: (_) => SearchStories(storyRepo)),
      Provider(create: (_) => GetRegionActivity(storyRepo)),
      Provider(create: (_) => GetTrendingStories(storyRepo, ranker)),
      Provider(create: (_) => PublishIntel(storyRepo)),
      // Media
      Provider(create: (_) => GetVideos(mediaRepo)),
      Provider(create: (_) => ToggleVideoLike(mediaRepo)),
      Provider(create: (_) => GetActiveStreams(mediaRepo)),
      Provider(create: (_) => CreateStream(mediaRepo)),
      Provider(create: (_) => SetStreamStatus(mediaRepo)),
      // Moderation
      Provider(create: (_) => GetPostModeration(moderationRepo)),
      Provider(create: (_) => SubmitNote(moderationRepo)),
      Provider(create: (_) => GetOpenClaims(moderationRepo)),
      Provider(create: (_) => ResolveClaim(moderationRepo)),
      Provider(create: (_) => SubmitFeedback(moderationRepo)),
      // Search
      Provider(create: (_) => SearchAll(searchRepo)),

      // ── Presentation state ──
      ChangeNotifierProvider(
        create: (context) => AuthProvider(
          repository: authRepo,
          signIn: context.read<SignIn>(),
          signUp: context.read<SignUp>(),
          signOut: context.read<SignOut>(),
          sendPasswordReset: context.read<SendPasswordReset>(),
          updatePassword: context.read<UpdatePassword>(),
          resendVerification: context.read<ResendVerification>(),
        ),
      ),

      // The profile follows whoever is signed in, so it is a proxy on
      // AuthProvider rather than something screens have to refresh by hand.
      ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
        create: (context) => ProfileProvider(
          getProfile: context.read<GetProfile>(),
          updateProfile: context.read<UpdateProfile>(),
          applyForOsint: context.read<ApplyForOsint>(),
          getMyApplication: context.read<GetMyApplication>(),
        ),
        update: (context, auth, profile) =>
            profile!..syncWithUser(auth.user?.id),
      ),

      ChangeNotifierProvider(
        create: (context) => FeedProvider(
          getFeed: context.read<GetFeed>(),
          createPost: context.read<CreatePost>(),
          toggleLike: context.read<ToggleLike>(),
          toggleSave: context.read<ToggleSave>(),
          toggleRepost: context.read<ToggleRepost>(),
          watchNewPosts: context.read<WatchNewPosts>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => StoryProvider(
          getStories: context.read<GetStories>(),
          getTrending: context.read<GetTrendingStories>(),
          publishIntel: context.read<PublishIntel>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => MediaProvider(
          getVideos: context.read<GetVideos>(),
          toggleVideoLike: context.read<ToggleVideoLike>(),
          getActiveStreams: context.read<GetActiveStreams>(),
          createStream: context.read<CreateStream>(),
          setStreamStatus: context.read<SetStreamStatus>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => ModerationProvider(
          getPostModeration: context.read<GetPostModeration>(),
          submitNote: context.read<SubmitNote>(),
          getOpenClaims: context.read<GetOpenClaims>(),
          resolveClaim: context.read<ResolveClaim>(),
          submitFeedback: context.read<SubmitFeedback>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            SearchProvider(searchAll: context.read<SearchAll>()),
      ),
    ];
  }
}

/// Convenience wrapper so `main` reads as one line.
class AppProviders extends StatelessWidget {
  const AppProviders({required this.child, this.themeStore, super.key});

  final Widget child;
  final ThemeStore? themeStore;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: Injection.providers(themeStore: themeStore),
      child: child,
    );
  }
}
