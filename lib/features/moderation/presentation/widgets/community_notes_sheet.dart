import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/community_note.dart';
import '../providers/moderation_provider.dart';

/// Community notes for one post, with the claim threshold made visible so
/// people can see how close a post is to being formally disputed.
class CommunityNotesSheet extends StatefulWidget {
  const CommunityNotesSheet({required this.postId, super.key});

  final int postId;

  static Future<void> show(BuildContext context, int postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CommunityNotesSheet(postId: postId),
    );
  }

  @override
  State<CommunityNotesSheet> createState() => _CommunityNotesSheetState();
}

class _CommunityNotesSheetState extends State<CommunityNotesSheet> {
  final _controller = TextEditingController();
  NoteStance _stance = NoteStance.supports;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ModerationProvider>().loadForPost(widget.postId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<ModerationProvider>();
    final ok = await provider.submitNote(
      widget.postId,
      _controller.text,
      _stance,
    );
    if (!mounted) return;

    if (ok) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.failure?.message ?? 'Could not add note.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModerationProvider>();
    final moderation = provider.forPost(widget.postId);
    final palette = context.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        if (moderation == null) return const AppLoader();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _ThresholdBar(moderation: moderation),
                    const SizedBox(height: AppSpacing.lg),
                    if (moderation.notes.isEmpty)
                      Text(
                        'No notes on this post yet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ...moderation.notes.map((n) => _NoteTile(note: n)),
                  ],
                ),
              ),
              if (moderation.myNote == null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: palette.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<NoteStance>(
                        segments: const [
                          ButtonSegment(
                            value: NoteStance.supports,
                            label: Text('Supports'),
                          ),
                          ButtonSegment(
                            value: NoteStance.challenges,
                            label: Text('Challenges'),
                          ),
                        ],
                        selected: {_stance},
                        onSelectionChanged: (s) => setState(() => _stance = s.first),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _controller,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Add context, with a source if you have one…',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: _controller.text.trim().length <
                                SubmitNoteMinimum.minLength
                            ? null
                            : _submit,
                        child: const Text('ADD NOTE'),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'You have already written a note on this post.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Local mirror of the use case's minimum so the button can disable early.
class SubmitNoteMinimum {
  const SubmitNoteMinimum._();
  static const int minLength = 15;
}

class _ThresholdBar extends StatelessWidget {
  const _ThresholdBar({required this.moderation});

  final PostModeration moderation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress =
        (moderation.challengeWeight / AppConstants.claimThreshold).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              moderation.isDisputed ? 'DISPUTED' : 'COMMUNITY NOTES',
              style: AppTypography.mono(
                size: 11,
                color: moderation.isDisputed ? palette.warn : palette.muted,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              '${moderation.supportWeight} support · ${moderation.challengeWeight} challenge',
              style: AppTypography.mono(size: 9, color: palette.muted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: palette.border,
            valueColor: AlwaysStoppedAnimation(
              moderation.isDisputed ? palette.warn : palette.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final CommunityNote note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = note.challenges ? palette.warn : palette.verified;

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
                note.challenges ? 'CHALLENGES' : 'SUPPORTS',
                style: AppTypography.mono(size: 9, color: color, letterSpacing: 1),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '@${note.author?.username ?? 'unknown'} · weight ${note.weight}',
                style: AppTypography.mono(size: 9, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(note.body, style: Theme.of(context).textTheme.bodySmall),
          if (note.accuracyRating != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'RATED ${note.accuracyRating!.toUpperCase()}',
              style: AppTypography.mono(size: 9, color: palette.accent),
            ),
          ],
        ],
      ),
    );
  }
}
