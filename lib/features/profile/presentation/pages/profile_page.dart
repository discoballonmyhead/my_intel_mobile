import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = profileProvider.profile;
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: profile == null
          ? const AppLoader()
          : ContentColumn(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: palette.surface2,
                        child: Text(
                          profile.username.characters.first.toUpperCase(),
                          style: AppTypography.mono(
                            size: 20,
                            color: palette.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            RoleBadge(role: profile.role),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      if (profile.isAnalyst)
                        _Stat(label: 'CREDIBILITY', value: '${profile.score}'),
                      _Stat(label: 'AURA', value: '${profile.auraPoints}'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!profile.isAnalyst)
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.applyOsint),
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('APPLY AS ANALYST'),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  if (profileProvider.isAdmin)
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.admin),
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: const Text('ADMIN DASHBOARD'),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  OutlinedButton(
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.accent2,
                    ),
                    child: const Text('SIGN OUT'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            label,
            style: AppTypography.mono(
              size: 9,
              color: palette.muted,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
