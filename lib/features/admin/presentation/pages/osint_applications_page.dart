import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/admin_entities.dart';
import '../cubits/osint_review_cubit.dart';

class OsintApplicationsPage extends StatelessWidget {
  const OsintApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OsintReviewCubit, OsintReviewState>(
      listenWhen: (a, b) =>
          (b.message != null && a.message != b.message) ||
          (b.actionFailure != null && a.actionFailure != b.actionFailure),
      listener: (context, state) {
        final text = state.actionFailure?.message ?? state.message;
        if (text != null) AppDialogs.snack(context, text);
        context.read<OsintReviewCubit>().clearFeedback();
      },
      builder: (context, state) {
        final cubit = context.read<OsintReviewCubit>();
        return Scaffold(
          appBar: AppBar(title: const Text('OSINT APPLICATIONS')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<OsintStatusFilter>(
                    segments: OsintStatusFilter.values
                        .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                        .toList(),
                    selected: {state.filter},
                    onSelectionChanged: (s) => cubit.setFilter(s.first),
                  ),
                ),
              ),
              Expanded(
                child: state.isLoading
                    ? const AppLoader()
                    : state.failure != null
                        ? AppErrorView(
                            failure: state.failure ?? const UnexpectedFailure(),
                            onRetry: cubit.load,
                          )
                        : state.items.isEmpty
                            ? const AppEmptyView(
                                message: 'No applications',
                                icon: Icons.verified_outlined,
                              )
                            : RefreshIndicator(
                                onRefresh: cubit.load,
                                child: ContentColumn(
                                  padded: false,
                                  child: ListView.builder(
                                    itemCount: state.items.length,
                                    itemBuilder: (context, index) {
                                      final item = state.items[index];
                                      return _ApplicationCard(
                                        item: item,
                                        busy: state.busyIds
                                            .contains(item.application.id),
                                      );
                                    },
                                  ),
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.item, required this.busy});

  final OsintApplicationReview item;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OsintReviewCubit>();
    final palette = context.palette;
    final theme = Theme.of(context);
    final app = item.application;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(app.channelName, style: theme.textTheme.titleMedium),
              ),
              Text(app.status.toUpperCase(),
                  style: AppTypography.mono(size: 9, color: palette.accent)),
            ],
          ),
          Text(
            '${app.handle} · @${item.profile?.username ?? 'unknown'}'
            '${item.email == null ? '' : ' · ${item.email}'}',
            style: AppTypography.mono(size: 9, color: palette.muted),
          ),
          if (app.createdAt != null)
            Text('Applied ${app.createdAt!.timeAgo}',
                style: AppTypography.mono(size: 9, color: palette.muted)),
          if ((app.portfolio ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText('Portfolio: ${app.portfolio}',
                style: theme.textTheme.bodySmall),
          ],
          if ((app.why ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(app.why!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (app.isPending) ...[
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final note = await AppDialogs.reason(context,
                              title: 'Approve ${app.channelName}',
                              hint: 'Note (optional)',
                              confirmLabel: 'APPROVE',
                              isRequired: false);
                          if (note != null) {
                            await cubit.approve(item,
                                note: note.isEmpty ? null : note);
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: palette.verified),
                  child: const Text('APPROVE'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final reason = await AppDialogs.reason(context,
                              title: 'Decline ${app.channelName}',
                              hint: 'Reason (shown to the applicant)',
                              confirmLabel: 'DECLINE',
                              destructive: true);
                          if (reason != null) await cubit.decline(item, reason);
                        },
                  style: OutlinedButton.styleFrom(foregroundColor: palette.accent2),
                  child: const Text('DECLINE'),
                ),
              ],
              if (item.isOsint)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final reason = await AppDialogs.reason(context,
                              title: 'Revoke analyst status',
                              hint: 'Reason (required, logged)',
                              confirmLabel: 'REVOKE',
                              destructive: true);
                          if (reason != null) await cubit.revoke(item, reason);
                        },
                  style: OutlinedButton.styleFrom(foregroundColor: palette.accent2),
                  child: const Text('REVOKE OSINT'),
                ),
              if (app.userId != null)
                TextButton(
                  onPressed: () =>
                      context.push(AppRoutes.adminUserFor(app.userId!)),
                  child: const Text('VIEW USER'),
                ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
