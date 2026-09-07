import 'package:flutter/material.dart';

import '../error/failures.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Renders a [Failure] with an optional retry. Because repositories always
/// return typed failures, the copy here can stay specific without the UI
/// having to inspect raw error strings.
class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  IconData get _icon => switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        PermissionFailure() => Icons.lock_outline_rounded,
        NotFoundFailure() => Icons.search_off_rounded,
        AuthFailure() => Icons.person_off_outlined,
        _ => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 30, color: palette.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, size: 28, color: context.palette.muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                size: 10,
                color: context.palette.muted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
