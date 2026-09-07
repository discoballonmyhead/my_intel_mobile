import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.palette.accent,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(
              label!.toUpperCase(),
              style: AppTypography.mono(
                size: 10,
                color: context.palette.muted,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
