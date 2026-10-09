import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/cubits/access_cubit.dart';
import '../../features/account/presentation/cubits/delete_account_cubit.dart';
import '../../features/account/presentation/pages/delete_account_page.dart';
import '../../features/account/presentation/pages/restricted_page.dart';
import '../../features/admin/presentation/cubits/admin_dashboard_cubit.dart';
import '../../features/admin/presentation/cubits/admin_user_detail_cubit.dart';
import '../../features/admin/presentation/cubits/admin_users_cubit.dart';
import '../../features/admin/presentation/cubits/audit_log_cubit.dart';
import '../../features/admin/presentation/cubits/osint_review_cubit.dart';
import '../../features/admin/presentation/pages/admin_home_page.dart';
import '../../features/admin/presentation/pages/admin_user_detail_page.dart';
import '../../features/admin/presentation/pages/admin_users_page.dart';
import '../../features/admin/presentation/pages/audit_log_page.dart';
import '../../features/admin/presentation/pages/osint_applications_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_cubit.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/media/presentation/pages/reels_page.dart';
import '../../features/messaging/presentation/cubits/chat_cubit.dart';
import '../../features/messaging/presentation/cubits/new_conversation_cubit.dart';
import '../../features/messaging/presentation/pages/chat_page.dart';
import '../../features/messaging/presentation/pages/inbox_page.dart';
import '../../features/messaging/presentation/pages/new_conversation_page.dart';
import '../../features/moderation/domain/entities/report.dart';
import '../../features/moderation/presentation/cubits/mod_queue_cubit.dart';
import '../../features/moderation/presentation/cubits/my_reports_cubit.dart';
import '../../features/moderation/presentation/cubits/report_detail_cubit.dart';
import '../../features/moderation/presentation/pages/admin_dashboard_page.dart';
import '../../features/account/presentation/pages/change_email_page.dart';
import '../../features/account/presentation/pages/change_password_page.dart';
import '../../features/moderation/presentation/pages/feedback_page.dart';
import '../../features/moderation/presentation/pages/mod_queue_page.dart';
import '../../features/moderation/presentation/pages/my_reports_page.dart';
import '../../features/moderation/presentation/pages/report_detail_page.dart';
import '../../features/profile/presentation/pages/apply_osint_page.dart';
import '../../features/profile/presentation/pages/channel_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/follow_list_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/settings_sub_pages.dart';
import '../../features/profile/presentation/providers/profile_cubit.dart';
import '../../features/profile/presentation/providers/transient_channel_cubit.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/shell/presentation/pages/app_shell.dart';
import '../../features/shell/presentation/pages/not_found_page.dart';
import '../../features/stories/presentation/pages/articles_page.dart';
import '../../features/stories/presentation/pages/story_detail_page.dart';
import '../di/injection.dart';
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
    required AccessCubit accessCubit,
  }) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.feed,
      refreshListenable: RouterRefreshStream([
        authCubit.stream,
        profileCubit.stream,
        accessCubit.stream,
      ]),
      debugLogDiagnostics: false,
      errorBuilder: (context, state) =>
          NotFoundPage(path: state.uri.toString()),
      redirect: (context, state) => _redirect(
        state,
        auth: authCubit.state,
        profile: profileCubit.state,
        access: accessCubit.state,
      ),
      routes: [
        // ── Auth ──
        GoRoute(
          path: AppRoutes.login,
          name: RouteNames.login,
          builder: (context, state) => const AuthPage(),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: RouteNames.register,
          builder: (context, state) => const AuthPage(startInSignUp: true),
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
        GoRoute(
          path: AppRoutes.restricted,
          name: RouteNames.restricted,
          builder: (context, state) => const RestrictedPage(),
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
                  path: AppRoutes.messages,
                  name: RouteNames.messages,
                  builder: (context, state) => const InboxPage(),
                  routes: [
                    // 'new' must stay above ':conversationId'.
                    GoRoute(
                      path: 'new',
                      name: RouteNames.newMessage,
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) =>
                          BlocProvider<NewConversationCubit>(
                        create: (_) => sl<NewConversationCubit>(
                            param1: const NewConversationArgs()),
                        child: const NewConversationPage(),
                      ),
                    ),
                    GoRoute(
                      path: ':conversationId',
                      name: RouteNames.chat,
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) {
                        final id = state.pathParameters['conversationId']!;
                        return BlocProvider<ChatCubit>(
                          key: ValueKey('chat-$id'),
                          create: (_) => sl<ChatCubit>(param1: id)..load(),
                          child: const ChatPage(),
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'add',
                          name: RouteNames.addMembers,
                          parentNavigatorKey: _rootKey,
                          builder: (context, state) =>
                              BlocProvider<NewConversationCubit>(
                            create: (_) => sl<NewConversationCubit>(
                              param1: NewConversationArgs(
                                addToConversationId:
                                    state.pathParameters['conversationId'],
                              ),
                            ),
                            child: const NewConversationPage(),
                          ),
                        ),
                      ],
                    ),
                  ],
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
          routes: [
            GoRoute(
              path: 'delete-account',
              name: RouteNames.deleteAccount,
              builder: (context, state) => BlocProvider<DeleteAccountCubit>(
                create: (_) => sl<DeleteAccountCubit>(),
                child: const DeleteAccountPage(),
              ),
            ),
            GoRoute(
              path: 'appearance',
              name: RouteNames.appearance,
              builder: (context, state) => const AppearancePage(),
            ),
            GoRoute(
              path: 'account',
              name: RouteNames.accountSettings,
              builder: (context, state) => const AccountSettingsPage(),
              routes: [
                GoRoute(
                  path: 'password',
                  name: RouteNames.changePassword,
                  builder: (context, state) => const ChangePasswordPage(),
                ),
                GoRoute(
                  path: 'email',
                  name: RouteNames.changeEmail,
                  builder: (context, state) => const ChangeEmailPage(),
                ),
              ],
            ),
            GoRoute(
              path: 'support',
              name: RouteNames.support,
              builder: (context, state) => const SupportPage(),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.followers,
          name: RouteNames.followers,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const FollowListPage(),
        ),
        GoRoute(
          path: AppRoutes.following,
          name: RouteNames.following,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const FollowListPage(showFollowing: true),
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
          path: AppRoutes.myReports,
          name: RouteNames.myReports,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => BlocProvider<MyReportsCubit>(
            create: (_) => sl<MyReportsCubit>()..load(),
            child: const MyReportsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.channel,
          name: RouteNames.channel,
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return BlocProvider<ChannelCubit>(
              key: ValueKey('channel-$username'),
              create: (_) => sl<ChannelCubit>()..load(username),
              child: ChannelPage(username: username),
            );
          },
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

        // ── Staff console (guarded in _redirect, enforced again by RPCs) ──
        GoRoute(
          path: AppRoutes.admin,
          name: RouteNames.admin,
          parentNavigatorKey: _rootKey,
          builder: (context, state) => BlocProvider<AdminDashboardCubit>(
            create: (_) => sl<AdminDashboardCubit>()..load(),
            child: const AdminHomePage(),
          ),
          routes: [
            GoRoute(
              path: 'users',
              name: RouteNames.adminUsers,
              builder: (context, state) => BlocProvider<AdminUsersCubit>(
                create: (_) => sl<AdminUsersCubit>()..load(),
                child: const AdminUsersPage(),
              ),
              routes: [
                GoRoute(
                  path: ':userId',
                  name: RouteNames.adminUser,
                  builder: (context, state) {
                    final userId = state.pathParameters['userId']!;
                    return BlocProvider<AdminUserDetailCubit>(
                      key: ValueKey('admin-user-$userId'),
                      create: (_) =>
                          sl<AdminUserDetailCubit>(param1: userId)..load(),
                      child: const AdminUserDetailPage(),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'reports',
              name: RouteNames.adminReports,
              builder: (context, state) => BlocProvider<ModQueueCubit>(
                create: (_) => sl<ModQueueCubit>()..load(),
                child: const ModQueuePage(),
              ),
              routes: [
                GoRoute(
                  path: ':type/:id',
                  name: RouteNames.adminReport,
                  builder: (context, state) {
                    final target = ReportTarget(
                      ReportTargetType.fromValue(state.pathParameters['type']),
                      state.pathParameters['id']!,
                    );
                    return BlocProvider<ReportDetailCubit>(
                      key: ValueKey('report-${target.type.value}-${target.id}'),
                      create: (_) =>
                          sl<ReportDetailCubit>(param1: target)..load(),
                      child: const ReportDetailPage(),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'osint',
              name: RouteNames.adminOsint,
              builder: (context, state) => BlocProvider<OsintReviewCubit>(
                create: (_) => sl<OsintReviewCubit>()..load(),
                child: const OsintApplicationsPage(),
              ),
            ),
            GoRoute(
              path: 'claims',
              name: RouteNames.adminClaims,
              builder: (context, state) => const AdminDashboardPage(),
            ),
            GoRoute(
              path: 'audit',
              name: RouteNames.adminAudit,
              builder: (context, state) => BlocProvider<AuditLogCubit>(
                create: (_) => sl<AuditLogCubit>()..load(),
                child: const AuditLogPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String? _redirect(
    GoRouterState state, {
    required AuthState auth,
    required ProfileState profile,
    required AccessState access,
  }) {
    final location = state.matchedLocation;
    final isPublic = AppRoutes.publicRoutes.contains(location);

    // The session exists but only to set a new password.
    if (auth.isRecovering) {
      return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
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

    // Banned / suspended accounts only see the restriction notice, and are
    // let back in as soon as AccessCubit reports the sanction lifted.
    if (access.isBanned) {
      return location == AppRoutes.restricted ? null : AppRoutes.restricted;
    }
    if (location == AppRoutes.restricted) return AppRoutes.feed;

    if (AppRoutes.isStaffRoute(location)) {
      // Legacy profiles.role = 'admin' still counts while access loads.
      final isAdmin = access.isAdmin || profile.isAdmin;
      final isStaff = access.isStaff || isAdmin;

      // Don't bounce a deep link before we know the user's roles; the
      // RouterRefreshStream re-runs this once AccessCubit resolves.
      if (!access.isResolved && !isStaff) return null;

      if (!isStaff) return AppRoutes.feed;
      if (!isAdmin && AppRoutes.adminOnlyRoutes.contains(location)) {
        return AppRoutes.admin;
      }
    }

    return null;
  }
}
