import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../domain/entities/profile.dart';
import '../providers/profile_cubit.dart';
import '../widgets/profile_ui.dart';

String themeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Match system',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

/// Settings: the analyst invitation on top (MINT's core), then Appearance,
/// Account and Support pages, then Sign out and Delete account.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final palette = context.palette;
    final yes = await showSoftSheet<bool>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign out of MINT?',
                style: inter(18,
                    weight: FontWeight.w600,
                    color: Theme.of(sheet).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('You can sign back in any time.',
                style: inter(15, color: palette.muted)),
            const SizedBox(height: 24),
            PillButton(
                label: 'Sign out', onPressed: () => Navigator.of(sheet).pop(true)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              style: TextButton.styleFrom(
                  foregroundColor: palette.muted,
                  textStyle: inter(15, weight: FontWeight.w500)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    // The router's auth redirect takes over once signed out.
    if (yes == true && context.mounted) await context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final palette = context.palette;
    final access = context.watch<AccessCubit>().state;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        final isAdmin = access.isAdmin || (profile?.role.isAdmin ?? false);
        final isStaff = access.isStaff || isAdmin;
        final showAnalystCard =
            profile != null && !profile.isAnalyst && !isStaff;

        return Scaffold(
          appBar: softAppBar(context, 'Settings'),
          body: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  // The router's auth redirect takes over once signed out.
                  onTap: () => context.read<AuthCubit>().signOut(),
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionLabel(label: 'SUPPORT'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Send feedback'),
                  subtitle: const Text('Report a bug or suggest an idea'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.feedback),
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

/// "Become an OSINT analyst" with a small Apply button, or the state of an
/// application that has been sent.
class _AnalystCard extends StatelessWidget {
  const _AnalystCard({required this.application});

  final OsintApplication? application;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final app = application;

    final (IconData icon, Color tint, String title, String body, String? action) =
        switch (app) {
      null => (
          Icons.verified_user_rounded,
          palette.accent,
          'Become an OSINT analyst',
          'MINT’s core: analysts publish intel that becomes the stories everyone reads.',
          'Apply',
        ),
      _ when app.isPending => (
          Icons.hourglass_empty_rounded,
          palette.warn,
          'Application in review',
          'We’ll let you know when a moderator has looked at it. This usually takes a few days.',
          null,
        ),
      _ when app.isRejected && app.canReapply() => (
          Icons.verified_user_rounded,
          palette.accent,
          'Application not approved',
          'You can apply again with more about your work.',
          'Apply again',
        ),
      _ when app.isRejected => (
          Icons.verified_user_rounded,
          palette.muted,
          'Application not approved',
          'You can apply again from '
              '${DateFormat('d MMM').format(app.reapplyAvailableAt!.toLocal())}.',
          null,
        ),
      _ => (
          Icons.verified_user_rounded,
          palette.accent,
          'Become an OSINT analyst',
          'MINT’s core: analysts publish intel that becomes the stories everyone reads.',
          'Apply',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: tint, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: inter(17, weight: FontWeight.w600, color: onSurface)),
                  const SizedBox(height: 4),
                  Text(body, style: inter(13, color: palette.muted, height: 1.4)),
                  if (action != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.applyOsint),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.only(left: 20, right: 16),
                        textStyle: inter(15, weight: FontWeight.w600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(action),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
