import 'package:flutter/material.dart';

import '../../../../core/constants/user_role.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/confidence_ring.dart';
import '../../domain/entities/story.dart';
import '../../domain/usecases/get_stories.dart';
import '../widgets/intel_message.dart';
import '../widgets/intel_story_card.dart';

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
    _fetch();
  }

  void _retry() {
    setState(() => _loading = true);
    _fetch();
  }

  Future<void> _fetch() async {
    final result = await sl<GetStory>()(widget.storyId);
    if (!mounted) return;
    setState(() {
      _story = result.valueOrNull;
      _failure = result.failureOrNull;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _loading
          ? const _StorySkeleton()
          : story == null
              ? IntelMessage(
                  icon: _failure is NotFoundFailure
                      ? Icons.search_off_rounded
                      : Icons.wifi_off_rounded,
                  title: _failure is NotFoundFailure
                      ? 'This story is no longer available'
                      : 'Can’t load this story',
                  body: _failure is NotFoundFailure
                      ? 'It may have been removed.'
                      : 'Check your connection and try again.',
                  action: _failure is NotFoundFailure ? null : 'Try again',
                  outlined: true,
                  onAction: _retry,
                )
              : ContentColumn(child: _StoryBody(story: story)),
    );
  }
}

class _StoryBody extends StatelessWidget {
  const _StoryBody({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final level = ConfidenceLevel.of(story.confidence);
    final summary = story.summary?.trim() ?? '';
    final sources = story.sourceCount;
    final why = sources == 0
        ? 'No sources yet'
        : sources == 1
            ? '1 source so far'
            : '$sources independent sources agree';

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 40),
      children: [
        StoryMetaLine(story: story),
        const SizedBox(height: 10),
        Text(story.headline,
            style: const TextStyle(
                fontSize: 26, height: 1.27, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Updated ${_updated(story.activityAt)}',
            style: TextStyle(fontSize: 14, color: palette.muted)),
        const SizedBox(height: 20),
        _SoftCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ConfidenceRing(confidence: story.confidence, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(why,
                        style: TextStyle(fontSize: 13, color: palette.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(summary, style: const TextStyle(fontSize: 16, height: 1.55)),
        ],
        const SizedBox(height: 28),
        const Text('Sources',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (story.sources.isEmpty)
          _SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Column(
              children: [
                const Text('No sources yet',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Reports that back up this story will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: palette.muted)),
              ],
            ),
          )
        else
          for (final s in story.sources) _SourceCard(source: s),
      ],
    );
  }
}

/// "just now", "3h ago", or a date ("25 Jul") once it is older than a week.
String _updated(DateTime t) {
  final ago = t.timeAgo;
  if (ago == 'now') return 'just now';
  return RegExp(r'^\d+[mhd]$').hasMatch(ago) ? '$ago ago' : ago;
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final StorySource source;

  static String _role(UserRole role) => switch (role) {
        UserRole.public => 'Member',
        UserRole.reporter => 'Reporter',
        UserRole.osint => 'OSINT analyst',
        UserRole.moderator => 'Moderator',
        UserRole.admin => 'Admin',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final author = source.author;
    final details = [
      if (author != null) _role(author.role),
      if (source.createdAt != null) source.createdAt!.timeAgo,
    ].join(' · ');
    final body = source.body?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _SoftCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(author?.username ?? 'Unknown',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (details.isNotEmpty)
                  Text(details,
                      style: TextStyle(fontSize: 13, color: palette.muted)),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body,
                  style: TextStyle(
                      fontSize: 14, height: 1.45, color: palette.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _StorySkeleton extends StatelessWidget {
  const _StorySkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.palette.surface2;
    Widget bar(double w, double h) => Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: w,
            height: h,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: block, borderRadius: BorderRadius.circular(h / 2)),
          ),
        );
    return ContentColumn(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
        children: [
          bar(160, 12),
          bar(double.infinity, 24),
          bar(260, 24),
          const SizedBox(height: 12),
          const _SoftCard(
              padding: EdgeInsets.zero, child: SizedBox(height: 84)),
          const SizedBox(height: 22),
          bar(double.infinity, 14),
          bar(double.infinity, 14),
          bar(240, 14),
        ],
      ),
    );
  }
}
