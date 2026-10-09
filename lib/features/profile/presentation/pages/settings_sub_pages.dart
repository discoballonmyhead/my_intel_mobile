import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../providers/profile_cubit.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_ui.dart';

/// Match system, Light or Dark.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    SettingsRow option(ThemeMode mode, String title, {String? subtitle}) =>
        SettingsRow(
          title: title,
          subtitle: subtitle,
          checked: theme.mode == mode,
          onTap: () => theme.setMode(mode),
        );
    return Scaffold(
      appBar: softAppBar(context, 'Appearance'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
          children: [
            const SectionLabel('Theme'),
            SettingsGroup([
              option(ThemeMode.system, 'Match system',
                  subtitle: 'Follows your iPhone setting'),
              option(ThemeMode.light, 'Light'),
              option(ThemeMode.dark, 'Dark'),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Username, email and password; role and member-since; My reports.
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = context.select<AuthCubit, AuthUser?>((c) => c.state.user);
    final email = user?.email ?? '';
    final pending = user?.pendingEmail;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        final since = profile?.createdAt == null
            ? '—'
            : DateFormat('MMMM yyyy').format(profile!.createdAt!.toLocal());
        return Scaffold(
          appBar: softAppBar(context, 'Account'),
          body: ContentColumn(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
              children: [
                SettingsGroup([
                  SettingsRow(
                    title: 'Username',
                    value: profile?.username ?? '—',
                    onTap: profile == null
                        ? null
                        : () async {
                            final saved =
                                await EditProfileSheet.show(context, profile.username);
                            if (saved && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated')));
                            }
                          },
                  ),
                  SettingsRow(
                    title: 'Email',
                    value: email,
                    subtitle: pending == null
                        ? null
                        : 'Confirm $pending from your inbox',
                    subtitleColor: palette.warn,
                    onTap: () => context.push(AppRoutes.changeEmail),
                  ),
                  SettingsRow(
                    title: 'Change password',
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                ]),
                SettingsGroup([
                  SettingsRow(
                    title: 'Role',
                    value: profile?.role.displayName ?? '—',
                    chevron: false,
                  ),
                  SettingsRow(title: 'Member since', value: since, chevron: false),
                ]),
                SettingsGroup([
                  SettingsRow(
                    title: 'My reports',
                    onTap: () => context.push(AppRoutes.myReports),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Send feedback.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: softAppBar(context, 'Support'),
      body: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
          children: [
            SettingsGroup([
              SettingsRow(
                title: 'Send feedback',
                subtitle: 'Report a bug or suggest an idea',
                onTap: () => context.push(AppRoutes.feedback),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
