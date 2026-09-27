import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../domain/entities/admin_entities.dart';
import '../cubits/admin_users_cubit.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<AdminUsersCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminUsersCubit, AdminUsersState>(
      builder: (context, state) {
        final cubit = context.read<AdminUsersCubit>();
        return Scaffold(
          appBar: AppBar(title: const Text('USERS')),
          body: ContentColumn(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: cubit.setSearch,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Username, email or user id',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Banned'),
                        selected: state.bannedOnly,
                        onSelected: cubit.setBannedOnly,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ...AppRole.values.map((role) => Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: FilterChip(
                              label: Text(role.label),
                              selected: state.role == role,
                              onSelected: (on) =>
                                  cubit.setRole(on ? role : null),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: state.isLoading
                      ? const AppLoader()
                      : state.failure != null && state.users.isEmpty
                          ? AppErrorView(
                              failure: state.failure ?? const UnexpectedFailure(),
                              onRetry: cubit.load,
                            )
                          : state.users.isEmpty
                              ? const AppEmptyView(message: 'No users match')
                              : RefreshIndicator(
                                  onRefresh: cubit.load,
                                  child: ListView.builder(
                                    controller: _scroll,
                                    itemCount: state.users.length +
                                        (state.isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= state.users.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(AppSpacing.md),
                                          child: AppLoader(),
                                        );
                                      }
                                      final user = state.users[index];
                                      return _UserTile(
                                        user: user,
                                        onTap: () async {
                                          await context.push(
                                              AppRoutes.adminUserFor(user.userId));
                                          if (context.mounted) cubit.load();
                                        },
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tags = <String>[
      ...user.roles.map((r) => r.label),
      if (user.isBanned) user.bannedUntil == null ? 'BANNED' : 'SUSPENDED',
      if (user.openReportsAgainst > 0) '${user.openReportsAgainst} OPEN REPORTS',
      if (user.latestOsintStatus == 'pending') 'OSINT PENDING',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: UserAvatar(name: user.displayName),
      title: Text(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.email != null)
            Text(user.email!,
                style: AppTypography.mono(size: 9, color: palette.muted)),
          if (tags.isNotEmpty)
            Text(
              tags.join(' · '),
              style: AppTypography.mono(
                size: 9,
                color: user.isBanned ? palette.accent2 : palette.accent,
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
