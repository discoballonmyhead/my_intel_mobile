import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effective = color ?? (selected ? palette.accent : palette.muted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? palette.activeBg : Colors.transparent,
          border: Border.all(
            color: selected ? effective.withValues(alpha: 0.5) : palette.border,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.mono(size: 9, color: effective, letterSpacing: 1),
        ),
      ),
    );
  }
}

/// Confidence read-out used on story cards (`content.stories.confidence`).
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({required this.confidence, super.key});

  final int confidence;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = confidence >= 70
        ? palette.verified
        : confidence >= 40
            ? palette.warn
            : palette.accent2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (confidence / 100).clamp(0, 1),
              minHeight: 3,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('$confidence%', style: AppTypography.mono(size: 9, color: color)),
      ],
    );
  }
}
