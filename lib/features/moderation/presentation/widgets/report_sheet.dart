import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/report.dart';
import '../cubits/report_cubit.dart';

/// Bottom sheet to report a post, message or profile. Owns its own
/// [ReportCubit] so any screen can open it with one call.
class ReportSheet extends StatelessWidget {
  const ReportSheet._({required this.target});

  final ReportTarget target;

  static Future<void> show(
    BuildContext context, {
    required ReportTargetType targetType,
    required String targetId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider<ReportCubit>(
        create: (_) => sl<ReportCubit>(),
        child: ReportSheet._(target: ReportTarget(targetType, targetId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return BlocBuilder<ReportCubit, ReportFormState>(
      builder: (context, state) {
        final cubit = context.read<ReportCubit>();

        if (state.isSubmitted) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 40, color: palette.verified),
                  const SizedBox(height: AppSpacing.md),
                  Text('Thanks for letting us know',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Our moderators will review this. You can follow the '
                    'outcome under Settings → My reports.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('DONE'),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (context, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                Text('Report ${target.type.label.toLowerCase()}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('Why are you reporting this?',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      value: reason,
                      groupValue: state.reason,
                      onChanged: state.isSubmitting
                          ? null
                          : (r) => cubit.selectReason(r!),
                      title: Text(reason.label),
                      subtitle: Text(reason.description),
                    )),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  enabled: !state.isSubmitting,
                  onChanged: cubit.setDetails,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: state.reason == ReportReason.other
                        ? 'Tell us what is wrong (required)'
                        : 'Anything else we should know? (optional)',
                    errorText: state.failure?.message,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed:
                      state.canSubmit ? () => cubit.submit(target) : null,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SUBMIT REPORT'),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}
