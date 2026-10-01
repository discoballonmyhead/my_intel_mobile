import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mint/features/profile/presentation/providers/profile_cubit.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_provider.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final responsive = context.watch<ResponsiveProvider>();
    final palette = context.palette;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile = state.profile;

        return Scaffold(
          appBar: AppBar(title: const Text('SETTINGS')),
          body: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                _SectionLabel(label: 'APPEARANCE'),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: theme.mode,
                  onChanged: (m) => theme.setMode(m!),
                  title: const Text('Follow system'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: theme.mode,
                  onChanged: (m) => theme.setMode(m!),
                  title: const Text('Ghost (light)'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: theme.mode,
                  onChanged: (m) => theme.setMode(m!),
                  title: const Text('Void (dark)'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel(label: 'ACCOUNT'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Username'),
                  subtitle: Text(profile?.username ?? '—'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Role'),
                  subtitle: Text(profile?.role.label ?? '—'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('My reports'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.myReports),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel(label: 'DANGER ZONE'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined,
                      color: palette.accent2),
                  title: Text('Delete account',
                      style: TextStyle(color: palette.accent2)),
                  subtitle: const Text('Permanently erase your account'),
                  onTap: () => context.push(AppRoutes.deleteAccount),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel(label: 'DIAGNOSTICS'),
                Text(
                  'Layout: ${responsive.deviceType.name} · '
                  '${responsive.width.toStringAsFixed(0)}×'
                  '${responsive.height.toStringAsFixed(0)}',
                  style: AppTypography.mono(size: 10, color: palette.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.mono(
          size: 10,
          color: context.palette.muted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
