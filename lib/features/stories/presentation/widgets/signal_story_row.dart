import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/signal_timeline.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/story.dart';

/// An Intel story on the Signal timeline: time and pin on the side line, then
/// a dispatch card with a BREAKING / INTEL strip, the headline, summary and
/// source count.
///
/// Pins: breaking stories pulse red while fresh, corroborated stories (3+
/// sources) are filled, developing ones are hollow.
class SignalStoryRow extends StatelessWidget {
  const SignalStoryRow({required this.story, this.onTap, super.key});

  final Story story;
  final VoidCallback? onTap;

  /// Breaking pins pulse while the story was active this recently.
  static const Duration freshFor = Duration(hours: 1);

  @override
  Widget build(BuildContext context) {
    final fresh =
        DateTime.now().toUtc().difference(story.activityAt.toUtc()) < freshFor;
    final pin = story.isBreaking
        ? SignalPin(kind: SignalPinKind.filled, pulse: fresh)
        : story.isCorroborated
            ? const SignalPin(kind: SignalPinKind.dimmed)
            : const SignalPin(kind: SignalPinKind.hollow);

    return SignalRow(
      time: story.activityAt,
      pin: pin,
      child: _StoryCard(story: story, onTap: onTap),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, this.onTap});

  final Story story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final summary = story.summary?.trim() ?? '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: story.isBreaking
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Strip(story: story),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.headline,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, height: 1.45, color: palette.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.layers_outlined,
                            size: 14,
                            color: story.isCorroborated
                                ? palette.verified
                                : palette.muted),
                        const SizedBox(width: 5),
                        Text(
                          '${story.sourceCount} '
                          '${story.sourceCount == 1 ? 'SOURCE' : 'SOURCES'}',
                          style: AppTypography.mono(
                            size: 10,
                            weight: FontWeight.w700,
                            letterSpacing: 1,
                            color: story.isCorroborated
                                ? palette.verified
                                : palette.muted,
                          ),
                        ),
                        if (story.isCorroborated) ...[
                          const SizedBox(width: 6),
                          Text('· CORROBORATED',
                              style: AppTypography.mono(
                                  size: 9,
                                  weight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: palette.verified)),
                        ],
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: palette.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "● BREAKING  KHARKIV  #CYBER" (red) or "● INTEL …" (green), with the
/// confidence meter on the right.
class _Strip extends StatelessWidget {
  const _Strip({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = story.isBreaking ? palette.accent : palette.verified;
    final region = story.region?.trim() ?? '';
    final tag = story.tag?.trim() ?? '';
    final style = AppTypography.mono(
        size: 9, weight: FontWeight.w700, letterSpacing: 1.3, color: color);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(story.isBreaking ? '● BREAKING' : '● INTEL', style: style),
                if (region.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(region.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(
                            color: story.isBreaking
                                ? Theme.of(context).colorScheme.onSurface
                                : palette.accent)),
                  ),
                ],
                if (tag.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('#${tag.toUpperCase()}',
                      style: style.copyWith(color: palette.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConfidenceMeter(confidence: story.confidence),
        ],
      ),
    );
  }
}
