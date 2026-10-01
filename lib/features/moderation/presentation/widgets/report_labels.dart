import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/report.dart';

IconData reportTargetIcon(ReportTargetType type) => switch (type) {
      ReportTargetType.post => Icons.article_outlined,
      ReportTargetType.message => Icons.chat_bubble_outline_rounded,
      ReportTargetType.profile => Icons.person_outline_rounded,
      ReportTargetType.video => Icons.movie_outlined,
      ReportTargetType.stream => Icons.podcasts_outlined,
      ReportTargetType.communityNote => Icons.sticky_note_2_outlined,
      ReportTargetType.story => Icons.newspaper_outlined,
      ReportTargetType.comment => Icons.mode_comment_outlined,
    };

class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip({required this.status, super.key});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (status) {
      ReportStatus.open => palette.warn,
      ReportStatus.inReview => palette.accent,
      ReportStatus.actioned => palette.verified,
      ReportStatus.dismissed => palette.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(status.label,
          style: AppTypography.mono(size: 8, color: color, letterSpacing: 1)),
    );
  }
}
