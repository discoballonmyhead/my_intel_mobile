import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_provider.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/profile_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final responsive = context.watch<ResponsiveProvider>();
    final profile = context.watch<ProfileProvider>().profile;
    final palette = context.palette;

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
