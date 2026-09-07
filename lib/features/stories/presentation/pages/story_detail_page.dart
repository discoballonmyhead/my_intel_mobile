import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/tag_chip.dart';
import '../../domain/entities/story.dart';
import '../../domain/usecases/get_stories.dart';

/// A story with its cited sources. Loads through the use case directly rather
/// than the list provider, so a deep link works without the list being warm.
class StoryDetailPage extends StatefulWidget {
  const StoryDetailPage({required this.storyId, super.key});

  final int storyId;

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  Story? _story;
  Failure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await context.read<GetStory>()(widget.storyId);
    if (!mounted) return;
    setState(() {
      _story = result.valueOrNull;
      _failure = result.failureOrNull;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final story = _story;

    return Scaffold(
      appBar: AppBar(title: const Text('STORY')),
      body: _loading
          ? const AppLoader()
          : story == null
              ? AppErrorView(
                  failure: _failure ?? const NotFoundFailure(),
                  onRetry: _load,
                )
              : ContentColumn(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    children: [
                      Row(
                        children: [
                          if (story.tag != null) TagChip(label: story.tag!),
                          const Spacer(),
                          ConfidenceMeter(confidence: story.confidence),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(story.headline, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${story.region ?? 'Global'} · updated ${story.activityAt.timeAgo}',
                        style: AppTypography.mono(size: 10, color: palette.muted),
                      ),
                      if (story.summary != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(story.summary!, style: theme.textTheme.bodyLarge),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'SOURCES (${story.sourceCount})',
                        style: AppTypography.mono(
                          size: 10,
                          color: palette.muted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...story.sources.map((s) => _SourceTile(source: s)),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final StorySource source;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = source.author;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '@${author?.username ?? 'unknown'}',
                style: AppTypography.mono(size: 10, color: palette.accent),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (author != null) RoleBadge(role: author.role, compact: true),
              const Spacer(),
              if (source.createdAt != null)
                Text(
                  source.createdAt!.timeAgo,
                  style: AppTypography.mono(size: 9, color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(source.body ?? '', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
