import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/post.dart';
import '../cubits/post_edit_history_cubit.dart';

class PostEditHistorySheet extends StatelessWidget {
  const PostEditHistorySheet._({required this.post});

  final Post post;

  static Future<void> show(BuildContext context, Post post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider<PostEditHistoryCubit>(
        create: (_) => sl<PostEditHistoryCubit>(param1: post.id)..load(),
        child: PostEditHistorySheet._(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          BlocBuilder<PostEditHistoryCubit, PostEditHistoryState>(
        builder: (context, state) {
          if (state.isLoading) return const AppLoader();
          if (state.failure != null) {
            return AppErrorView(
              failure: state.failure!,
              onRetry: context.read<PostEditHistoryCubit>().load,
            );
          }
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              Text('Edit history',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _Version(
                label: 'CURRENT · ${post.editedAt?.absolute ?? ''}',
                body: post.body,
                highlight: true,
              ),
              ...state.edits.map((e) => _Version(
                    label: 'BEFORE ${e.editedAt.absolute.toUpperCase()}',
                    body: e.previousBody,
                  )),
              if (state.edits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('No earlier versions.',
                      style: AppTypography.mono(size: 10, color: palette.muted)),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({required this.label, required this.body, this.highlight = false});

  final String label;
  final String body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: highlight ? palette.accent : palette.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.mono(
                  size: 9, color: highlight ? palette.accent : palette.muted)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
