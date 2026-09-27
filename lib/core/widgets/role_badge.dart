import 'package:flutter/material.dart';

import '../constants/user_role.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, this.compact = false, super.key});

  final UserRole role;
  final bool compact;

  IconData get _icon => switch (role) {
        UserRole.osint => Icons.verified_outlined,
        UserRole.reporter => Icons.edit_outlined,
        UserRole.moderator => Icons.gavel_outlined,
        UserRole.admin => Icons.shield_outlined,
        UserRole.public => Icons.circle_outlined,
      };

  Color _color(BuildContext context) => switch (role) {
        UserRole.osint => context.palette.verified,
        UserRole.reporter => context.palette.accent,
        UserRole.moderator => context.palette.warn,
        UserRole.admin => const Color(0xFFFF9F43),
        UserRole.public => context.palette.muted,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    if (compact) return Icon(_icon, size: 12, color: color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            role.label,
            style: AppTypography.mono(size: 9, color: color, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
