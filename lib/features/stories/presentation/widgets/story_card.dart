import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/story.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({required this.story, this.onTap, super.key});

  final Story story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (story.isBreaking) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.accent2,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      'BREAKING',
                      style: AppTypography.mono(
                        size: 8,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (story.tag != null) TagChip(label: story.tag!),
                const Spacer(),
                Text(
                  story.activityAt.timeAgo,
                  style: AppTypography.mono(size: 9, color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              story.headline,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
            ),
            if (story.summary != null && story.summary!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                story.summary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 12, color: palette.muted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${story.sourceCount} '
                  '${story.sourceCount == 1 ? 'SOURCE' : 'SOURCES'}',
                  style: AppTypography.mono(
                    size: 9,
                    color: story.isCorroborated ? palette.verified : palette.muted,
                  ),
                ),
                if (story.region != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.place_outlined, size: 12, color: palette.muted),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      story.region!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.mono(size: 9, color: palette.muted),
                    ),
                  ),
                ],
                const Spacer(),
                ConfidenceMeter(confidence: story.confidence),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
