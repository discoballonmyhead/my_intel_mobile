import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/confidence_ring.dart';
import '../../domain/entities/story.dart';

/// One story in the Intel list: a soft card with a quiet details line, the
/// headline, a short summary and a small confidence ring. Red is used only
/// for breaking stories.
class IntelStoryCard extends StatelessWidget {
  const IntelStoryCard({required this.story, this.onTap, super.key});

  final Story story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final summary = story.summary?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoryMetaLine(story: story),
                      const SizedBox(height: 8),
                      Text(
                        story.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w600),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14, height: 1.4, color: palette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConfidenceRing(confidence: story.confidence),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Maritime · Asia Pacific · 3h", or "● Breaking · Middle East · 40m" in red.
class StoryMetaLine extends StatelessWidget {
  const StoryMetaLine({required this.story, super.key});

  final Story story;

  static String _title(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final raw = story.region?.trim() ?? '';
    // Some regions are stored lower-case ("global"); capitalise the first letter.
    final region = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
    final tag = _title(story.tag?.trim() ?? '');
    final rest = [
      if (!story.isBreaking && tag.isNotEmpty) tag,
      if (region.isNotEmpty) region,
      story.activityAt.timeAgo,
    ].join(' · ');
    final muted = TextStyle(fontSize: 13, color: palette.muted);

    if (!story.isBreaking) return Text(rest, style: muted);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: palette.accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('Breaking',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.accent)),
        Flexible(
          child:
              Text(' · $rest', style: muted, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Soft placeholder card shown while stories load.
class IntelStoryCardSkeleton extends StatelessWidget {
  const IntelStoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final block = context.palette.surface2;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: block, borderRadius: BorderRadius.circular(h / 2)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(140, 12),
                  const SizedBox(height: 14),
                  bar(double.infinity, 16),
                  const SizedBox(height: 6),
                  bar(200, 16),
                  const SizedBox(height: 14),
                  bar(double.infinity, 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: block, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
