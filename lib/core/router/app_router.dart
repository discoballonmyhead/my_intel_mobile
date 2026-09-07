import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/media/presentation/pages/live_page.dart';
import '../../features/media/presentation/pages/reels_page.dart';
import '../../features/moderation/presentation/pages/admin_dashboard_page.dart';
import '../../features/moderation/presentation/pages/feedback_page.dart';
import '../../features/profile/presentation/pages/apply_osint_page.dart';
import '../../features/profile/presentation/pages/channel_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shell/presentation/pages/app_shell.dart';
import '../../features/shell/presentation/pages/not_found_page.dart';
import '../../features/stories/presentation/pages/articles_page.dart';
import '../../features/stories/presentation/pages/story_detail_page.dart';
import 'app_routes.dart';
import 'router_refresh.dart';

/// Builds the app's router.
///
/// Redirect rules, in order:
///   1. A password-recovery session goes to the reset form and nowhere else.
///   2. Signed-out users are pushed to /login, keeping the intended
///      destination so they land there after signing in.
///   3. Signed-in users on an auth screen are moved into the feed.
///   4. /admin additionally requires the admin role.
class AppRouter {
  const AppRouter._();

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  static GoRouter build({
    required AuthProvider auth,
    required ProfileProvider profile,
  }) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.feed,
      refreshListenable: RouterRefresh(auth),
      debugLogDiagnostics: false,
      errorBuilder: (context, state) =>
          NotFoundPage(path: state.uri.toString()),
      redirect: (context, state) {
        final location = state.matchedLocation;
        final isPublic = AppRoutes.publicRoutes.contains(location);

        // The session exists but only to set a new password.
        if (auth.isRecovering) {
          return location == AppRoutes.resetPassword
              ? null
              : AppRoutes.resetPassword;
        }

        if (!auth.isAuthenticated) {
          if (isPublic) return null;
          final from = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.login}?from=$from';
        }

        // Signed in: an auth screen is no longer the right place to be.
        if (isPublic) {
          final from = state.uri.queryParameters['from'];
          return from == null ? AppRoutes.feed : Uri.decodeComponent(from);
        }

        if (location == AppRoutes.admin && !profile.isAdmin) {
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
        // Each branch keeps its own navigation stack, so switching tabs does
        // not reset scroll position or lose a pushed detail page.
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
                  path: AppRoutes.live,
                  name: RouteNames.live,
                  builder: (context, state) => const LivePage(),
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
