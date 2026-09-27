import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../cubits/access_cubit.dart';

/// Shown while the account has an active ban or suspension. The router sends
/// banned users here and lets them out as soon as [AccessCubit] reports the
/// restriction lifted (realtime on `admin.sanctions`).
class RestrictedPage extends StatelessWidget {
  const RestrictedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AccessCubit, AccessState>(
          builder: (context, state) {
            final restriction = state.access.activeRestriction;
            return ContentColumn(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.block_rounded, size: 40, color: palette.accent2),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    restriction == null || restriction.isPermanent
                        ? 'Your account has been banned'
                        : 'Your account is suspended',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (restriction != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      restriction.reason,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      restriction.expiresAt == null
                          ? 'PERMANENT'
                          : 'UNTIL ${restriction.expiresAt!.absolute.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: AppTypography.mono(
                          size: 10, color: palette.muted, letterSpacing: 1.5),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  OutlinedButton(
                    onPressed: () => context.read<AccessCubit>().refresh(),
                    child: const Text('CHECK AGAIN'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    child: const Text('SIGN OUT'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
