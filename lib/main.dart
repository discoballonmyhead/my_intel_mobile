import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/di/injection.dart';
import 'core/network/supabase_bootstrap.dart';
import 'core/responsive/responsive_scope.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/profile/presentation/providers/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phone-first: lock to portrait so the bottom-nav layout is the default
  // experience. Tablets and desktop still get the rail via the breakpoints.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SupabaseServiceBootstrap.run();

  runApp(const AppProviders(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built once and kept — rebuilding a GoRouter would drop the whole
    // navigation stack on every theme or auth notification.
    _router ??= AppRouter.build(
      auth: context.read<AuthProvider>(),
      profile: context.read<ProfileProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'MINT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      routerConfig: _router!,
      // ResponsiveScope sits above every route, so the shell, the pages and
      // any dialog all read the same screen metrics.
      builder: (context, child) => ResponsiveScope(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
