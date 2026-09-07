import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({this.path, super.key});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '404',
                style: AppTypography.mono(
                  size: 40,
                  color: palette.accent,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                path == null ? 'No such page.' : 'No route for $path',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => context.go(AppRoutes.feed),
                child: const Text('BACK TO FEED'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
