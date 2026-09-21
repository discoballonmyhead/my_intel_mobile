import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mint/core/responsive/responsive_provider.dart';
import 'package:mint/features/feed/presentation/providers/feed_provider.dart';
import 'package:mint/features/media/presentation/providers/media_provider.dart';
import 'package:mint/features/moderation/presentation/providers/moderation_provider.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';
import 'package:mint/features/search/presentation/providers/search_provider.dart';
import 'package:mint/features/stories/presentation/providers/story_provider.dart';
import 'package:provider/provider.dart';

import 'core/di/injection.dart';
import 'core/network/supabase_bootstrap.dart';
import 'core/responsive/responsive_scope.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SupabaseServiceBootstrap.run();
  await Injection.init();

  runApp(const AppProviders(child: MyApp()));
}

class AppProviders extends StatelessWidget {
  const AppProviders({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sl<ThemeProvider>()),
        ChangeNotifierProvider.value(value: sl<ResponsiveProvider>()),
        ChangeNotifierProvider.value(value: sl<FeedProvider>()),
        ChangeNotifierProvider.value(value: sl<StoryProvider>()),
        ChangeNotifierProvider.value(value: sl<MediaProvider>()),
        ChangeNotifierProvider.value(value: sl<ModerationProvider>()),
        ChangeNotifierProvider.value(value: sl<SearchProvider>()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sl<AuthCubit>()),
          BlocProvider.value(value: sl<ProfileCubit>()),
        ],
        // ── THE PROPER WAY TO SYNC CUBITS IN FLUTTER_BLOC ──
        child: BlocListener<AuthCubit, AuthState>(
          // Only trigger the listener if the actual user ID changes
          listenWhen: (previous, current) =>
              previous.user?.id != current.user?.id,
          listener: (context, state) {
            // Tell the ProfileCubit to load the new user (or clear if null)
            context.read<ProfileCubit>().syncWithUser(state.user?.id);
          },
          child: child, // This is your MyApp()
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Built once directly from GetIt singletons in initState.
    // Re-evaluations happen internally via the RouterRefreshStream.
    _router = AppRouter.build(
      authCubit: sl<AuthCubit>(),
      profileCubit: sl<ProfileCubit>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'bobo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      routerConfig: _router,
      builder: (context, child) => ResponsiveScope(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
