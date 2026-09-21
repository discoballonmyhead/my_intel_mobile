import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_cubit.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/media/presentation/pages/reels_page.dart';
import '../../features/moderation/presentation/pages/admin_dashboard_page.dart';
import '../../features/moderation/presentation/pages/feedback_page.dart';
import '../../features/profile/presentation/pages/apply_osint_page.dart';
import '../../features/profile/presentation/pages/channel_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shell/presentation/pages/app_shell.dart';
import '../../features/shell/presentation/pages/not_found_page.dart';
import '../../features/stories/presentation/pages/articles_page.dart';
import '../../features/stories/presentation/pages/story_detail_page.dart';
import 'app_routes.dart';

/// Bridges multiple Cubit streams into a single Listenable for GoRouter.
class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(List<Stream<dynamic>> streams) {
    notifyListeners();
    for (final stream in streams) {
      _subscriptions.add(stream.listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription> _subscriptions = [];

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static GoRouter build({
    required AuthCubit authCubit,
    required ProfileCubit profileCubit,
  }) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.feed,
      // Listen to both Cubits natively!
      refreshListenable: RouterRefreshStream([
        authCubit.stream,
        profileCubit.stream,
      ]),
      debugLogDiagnostics: false,
      errorBuilder: (context, state) =>
          NotFoundPage(path: state.uri.toString()),

      redirect: (context, state) {
        final location = state.matchedLocation;
        final isPublic = AppRoutes.publicRoutes.contains(location);

        final authState = authCubit.state;
        final profileState = profileCubit.state;

        // The session exists but only to set a new password.
        if (authState.isRecovering) {
          return location == AppRoutes.resetPassword
              ? null
              : AppRoutes.resetPassword;
        }

        if (!authState.isAuthenticated) {
          if (isPublic) return null;
          final from = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.login}?from=$from';
        }

        // Signed in: an auth screen is no longer the right place to be.
        if (isPublic) {
          final from = state.uri.queryParameters['from'];
          return from == null ? AppRoutes.feed : Uri.decodeComponent(from);
        }

        // Admin gatekeeping mapped directly to the ProfileState
        if (location == AppRoutes.admin && !profileState.isAdmin) {
          return AppRoutes.feed;
        }

        return null;
      },
      routes: [
        // ── Auth ──
        GoRoute(
          path: AppRoutes.login,
          name: RouteNames.login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: RouteNames.register,
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: AppRoutes.verifyEmail,
          name: RouteNames.verifyEmail,
          builder: (context, state) => VerifyEmailPage(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          name: RouteNames.forgotPassword,
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          name: RouteNames.resetPassword,
          builder: (context, state) => const ResetPasswordPage(),
        ),

        // ── Tabbed shell ──
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              navigatorKey: _shellKey,
              routes: [
                GoRoute(
                  path: AppRoutes.feed,
                  name: RouteNames.feed,
                  builder: (context, state) => const FeedPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.articles,
                  name: RouteNames.articles,
                  builder: (context, state) => const ArticlesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.reels,
                  name: RouteNames.reels,
                  builder: (context, state) => const ReelsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  name: RouteNames.profile,
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),

        // ── Pushed over the shell ──
        GoRoute(
          path: AppRoutes.search,
          name: RouteNames.search,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: RouteNames.settings,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: AppRoutes.feedback,
          name: RouteNames.feedback,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const FeedbackPage(),
        ),
        GoRoute(
          path: AppRoutes.applyOsint,
          name: RouteNames.applyOsint,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const ApplyOsintPage(),
        ),
        GoRoute(
          path: AppRoutes.admin,
          name: RouteNames.admin,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: AppRoutes.channel,
          name: RouteNames.channel,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => ChannelPage(
            username: state.pathParameters['username'] ?? '',
          ),
        ),
        GoRoute(
          path: AppRoutes.story,
          name: RouteNames.story,
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) return const NotFoundPage();
            return StoryDetailPage(storyId: id);
          },
        ),
      ],
    );
  }
}
