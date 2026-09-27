import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../cubits/admin_dashboard_cubit.dart';
import '../widgets/stat_tile.dart';

/// Console landing page. Moderators see reports and users; admins also get
/// OSINT review, claims and the audit log.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessCubit>().state;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(access.isAdmin ? 'ADMIN' : 'MODERATION'),
      ),
      body: BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
        builder: (context, state) {
          final stats = state.stats;
          return RefreshIndicator(
            onRefresh: context.read<AdminDashboardCubit>().load,
            child: ContentColumn(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  if (state.isLoading && stats == null)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (stats == null && state.failure != null)
                    AppErrorView(
                      failure: state.failure!,
                      onRetry: context.read<AdminDashboardCubit>().load,
                    )
                  else if (stats != null)
                    GridView.count(
                      crossAxisCount:
                          MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 2.2,
                      children: [
                        StatTile(
                          label: 'OPEN REPORTS',
                          value: stats.openReportTargets,
                          highlight: true,
                          onTap: () => context.push(AppRoutes.adminReports),
                        ),
                        StatTile(
                          label: 'PENDING OSINT',
                          value: stats.pendingOsint,
                          highlight: true,
                          onTap: access.isAdmin
                              ? () => context.push(AppRoutes.adminOsint)
                              : null,
                        ),
                        StatTile(
                          label: 'POSTS IN REVIEW',
                          value: stats.postsUnderReview,
                          highlight: true,
                        ),
                        StatTile(label: 'ACTIVE BANS', value: stats.activeBans),
                        StatTile(label: 'USERS', value: stats.usersTotal),
                        StatTile(label: 'NEW USERS 7D', value: stats.usersNew7d),
                        StatTile(label: 'ANALYSTS', value: stats.osintUsers),
                        StatTile(label: 'POSTS 24H', value: stats.posts24h),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('TOOLS',
                      style: AppTypography.mono(
                          size: 10, color: palette.muted, letterSpacing: 1.5)),
                  const SizedBox(height: AppSpacing.sm),
                  _NavTile(
                    icon: Icons.flag_outlined,
                    title: 'Reports queue',
                    subtitle: 'Review reported posts, messages and profiles',
                    route: AppRoutes.adminReports,
                  ),
                  _NavTile(
                    icon: Icons.people_alt_outlined,
                    title: 'Users',
                    subtitle: 'Search, warn, suspend or ban',
                    route: AppRoutes.adminUsers,
                  ),
                  if (access.isAdmin) ...[
                    _NavTile(
                      icon: Icons.verified_outlined,
                      title: 'OSINT applications',
                      subtitle: 'Approve or decline analyst requests',
                      route: AppRoutes.adminOsint,
                    ),
                    _NavTile(
                      icon: Icons.gavel_outlined,
                      title: 'Credibility claims',
                      subtitle: 'Resolve community-note claims',
                      route: AppRoutes.adminClaims,
                    ),
                    _NavTile(
                      icon: Icons.history_rounded,
                      title: 'Audit log',
                      subtitle: 'Every staff action, who and why',
                      route: AppRoutes.adminAudit,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        await context.push(route);
        if (context.mounted) context.read<AdminDashboardCubit>().load();
      },
    );
  }
}
