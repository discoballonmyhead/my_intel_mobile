import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/reaction.dart';
import '../cubits/reactions_cubit.dart';

/// Verified · Confirmed · Disputed · Breaking — same icons and colours as the
/// web REACTION_TYPES. One reaction per person; tapping yours removes it.
class ReactionBar extends StatefulWidget {
  const ReactionBar({required this.postId, super.key});

  final int postId;

  static IconData iconOf(ReactionType type) => switch (type) {
        ReactionType.verified => Icons.verified_user_outlined,
        ReactionType.confirmed => Icons.star_outline_rounded,
        ReactionType.disputed => Icons.warning_amber_rounded,
        ReactionType.breaking => Icons.bolt_rounded,
      };

  static Color colorOf(BuildContext context, ReactionType type) {
    final palette = context.palette;
    return switch (type) {
      ReactionType.verified => palette.verified,
      ReactionType.confirmed => const Color(0xFFFF9F43),
      ReactionType.disputed => palette.accent2,
      ReactionType.breaking => palette.accent,
    };
  }

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  @override
  void initState() {
    super.initState();
    context.read<ReactionsCubit>().request([widget.postId]);
  }

  @override
  void didUpdateWidget(covariant ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      context.read<ReactionsCubit>().request([widget.postId]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ReactionsCubit, ReactionsState,
        (ReactionSummary?, bool)>(
      selector: (s) => (s.byPost[widget.postId], s.pending.contains(widget.postId)),
      builder: (context, data) {
        final (summary, busy) = data;
        final cubit = context.read<ReactionsCubit>();
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final type in ReactionType.values)
              _ReactionChip(
                type: type,
                count: summary?.countOf(type) ?? 0,
                selected: summary?.userReaction == type,
                onTap: busy || summary == null
                    ? null
                    : () => cubit.toggle(widget.postId, type),
              ),
          ],
        );
      },
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.type,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final ReactionType type;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = ReactionBar.colorOf(context, type);
    final fg = selected ? color : palette.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label}, $count',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : null,
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : palette.border,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ReactionBar.iconOf(type), size: 14, color: fg),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Text('$count', style: AppTypography.mono(size: 10, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
