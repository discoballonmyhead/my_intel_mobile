import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Initial-letter avatar used across messaging, admin and moderation lists.
class UserAvatar extends StatelessWidget {
  const UserAvatar({this.name, this.radius = 18, this.icon, super.key});

  final String? name;
  final double radius;

  /// Shown instead of the initial (e.g. a group icon, or a deleted user).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trimmed = name?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.surface2,
      child: icon != null || trimmed.isEmpty
          ? Icon(icon ?? Icons.person_off_outlined,
              size: radius, color: palette.muted)
          : Text(
              trimmed.characters.first.toUpperCase(),
              style: AppTypography.mono(size: radius * 0.8, color: palette.accent),
            ),
    );
  }
}
