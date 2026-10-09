import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/post_extras.dart';

String pollTimeLeft(DateTime endsAt, DateTime now) {
  final left = endsAt.difference(now);
  if (left.inMinutes < 60) return '${left.inMinutes.clamp(1, 59)}m left';
  if (left.inHours < 24) return '${left.inHours}h left';
  return '${left.inDays}d left';
}

/// A post's poll. Before the viewer votes it shows one button per option;
/// after voting, or once the poll has ended, it shows the results with the
/// viewer's pick marked. Votes are final.
class PostPollView extends StatefulWidget {
  const PostPollView({required this.poll, this.onVote, super.key});

  final PostPoll poll;

  /// Returns whether the vote went through. Null hides the vote buttons.
  final Future<bool> Function(int optionId)? onVote;

  @override
  State<PostPollView> createState() => _PostPollViewState();
}

class _PostPollViewState extends State<PostPollView> {
  int? _pendingId;

  Future<void> _vote(int optionId) async {
    final onVote = widget.onVote;
    if (onVote == null || _pendingId != null) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pendingId = optionId);
    await onVote(optionId);
    if (mounted) setState(() => _pendingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final poll = widget.poll;
    final now = DateTime.now().toUtc();
    final closed = poll.closedAt(now);
    final showResults = closed || poll.hasVoted || widget.onVote == null;
    final total = poll.totalVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in poll.options) ...[
          if (showResults)
            _ResultRow(
              option: option,
              total: total,
              mine: option.id == poll.myOptionId,
            )
          else
            OutlinedButton(
              onPressed: _pendingId == null ? () => _vote(option.id) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface,
                minimumSize: const Size.fromHeight(40),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                side: BorderSide(color: palette.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    // The theme's button text is the mono label style; poll
                    // options read as body text.
                    child: Text(option.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            color: onSurface)),
                  ),
                  if (_pendingId == option.id)
                    const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
        Text(
          '$total ${total == 1 ? 'vote' : 'votes'} · '
          '${closed ? 'Final results' : pollTimeLeft(poll.endsAt, now)}',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(
      {required this.option, required this.total, required this.mine});

  final PollOption option;
  final int total;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pct = total == 0 ? 0 : (option.votes * 100 / total).round();

    return Semantics(
      label: '${option.label}: $pct percent${mine ? ', your vote' : ''}',
      excludeSemantics: true,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: mine
                  ? palette.accent.withValues(alpha: 0.6)
                  : palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: pct / 100,
              heightFactor: 1,
              child: ColoredBox(
                  color: palette.accent.withValues(alpha: mine ? 0.18 : 0.10)),
            ),
            // Fills the row so the label and percentage sit in the middle.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: mine
                                      ? FontWeight.w600
                                      : FontWeight.w500)),
                    ),
                    if (mine) ...[
                      Icon(Icons.check_circle_rounded,
                          size: 16, color: palette.accent),
                      const SizedBox(width: 6),
                    ],
                    Text('$pct%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
