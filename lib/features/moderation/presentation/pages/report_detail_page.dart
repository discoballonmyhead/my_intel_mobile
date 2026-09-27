import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../admin/presentation/widgets/ban_user_dialog.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../domain/entities/report.dart';
import '../cubits/report_detail_cubit.dart';
import '../widgets/report_labels.dart';

class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key});

  Future<void> _remove(BuildContext context, ReportDetailCubit cubit) async {
    final target = cubit.state.target;
    final reason = await AppDialogs.reason(
      context,
      title: 'Remove ${target.type.label.toLowerCase()}',
      hint: 'Reason (logged, shown to the owner)',
      confirmLabel: 'REMOVE',
      destructive: true,
    );
    if (reason == null) return;
    final ok = await cubit.removeContent(reason);
    if (ok && context.mounted && target.type == ReportTargetType.post) {
      final id = int.tryParse(target.id);
      if (id != null) context.read<FeedProvider>().removeLocally(id);
    }
  }

  Future<void> _sanction(BuildContext context, ReportDetailCubit cubit) async {
    final owner = cubit.state.latest?.snapshot.raw?['username'] as String?;
    final request = await BanUserDialog.show(
      context,
      username: owner == null ? 'the owner' : '@$owner',
      allowPermanent: context.read<AccessCubit>().state.isAdmin,
    );
    if (request == null) return;
    await cubit.sanctionOwner(
      reason: request.reason,
      duration: request.duration,
      hideContent: request.hideContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportDetailCubit, ReportDetailState>(
      listenWhen: (a, b) =>
          (b.message != null && a.message != b.message) ||
          (b.actionFailure != null && a.actionFailure != b.actionFailure),
      listener: (context, state) {
        final text = state.actionFailure?.message ?? state.message;
        if (text != null) AppDialogs.snack(context, text);
        context.read<ReportDetailCubit>().clearFeedback();
        if (state.isResolved && context.canPop()) context.pop(true);
      },
      builder: (context, state) {
        final cubit = context.read<ReportDetailCubit>();
        final palette = context.palette;
        final theme = Theme.of(context);
        final target = state.target;

        return Scaffold(
          appBar: AppBar(
            title: Text('${target.type.label.toUpperCase()} #${target.id}'),
          ),
          body: state.isLoading
              ? const AppLoader()
              : state.failure != null && state.reports.isEmpty
                  ? AppErrorView(
                      failure: state.failure ?? const UnexpectedFailure(),
                      onRetry: cubit.load,
                    )
                  : ContentColumn(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg),
                        children: [
                          _SnapshotCard(snapshot: state.snapshot),
                          const SizedBox(height: AppSpacing.lg),
                          if (state.ownerId != null)
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                  AppRoutes.adminUserFor(state.ownerId!)),
                              icon: const Icon(Icons.person_search_outlined,
                                  size: 16),
                              label: const Text('VIEW OWNER'),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                          if (state.hasPending) ...[
                            Text('ACTIONS',
                                style: AppTypography.mono(
                                    size: 10,
                                    color: palette.muted,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                OutlinedButton(
                                  onPressed: state.isBusy ? null : cubit.claim,
                                  child: const Text('CLAIM'),
                                ),
                                OutlinedButton(
                                  onPressed: state.isBusy
                                      ? null
                                      : () async {
                                          final note = await AppDialogs.reason(
                                            context,
                                            title: 'Dismiss reports',
                                            hint: 'Note (optional)',
                                            confirmLabel: 'DISMISS',
                                            isRequired: false,
                                          );
                                          if (note != null) {
                                            await cubit.dismiss(
                                                note.isEmpty ? null : note);
                                          }
                                        },
                                  child: const Text('NO VIOLATION'),
                                ),
                                FilledButton(
                                  onPressed: state.isBusy
                                      ? null
                                      : () => _remove(context, cubit),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: palette.accent2),
                                  child: const Text('REMOVE CONTENT'),
                                ),
                                if (state.ownerId != null) ...[
                                  OutlinedButton(
                                    onPressed: state.isBusy
                                        ? null
                                        : () async {
                                            final reason =
                                                await AppDialogs.reason(
                                              context,
                                              title: 'Warn owner',
                                              hint: 'Reason (shown to the user)',
                                              confirmLabel: 'WARN',
                                            );
                                            if (reason != null) {
                                              await cubit.warnOwner(reason);
                                            }
                                          },
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: palette.warn),
                                    child: const Text('WARN OWNER'),
                                  ),
                                  OutlinedButton(
                                    onPressed: state.isBusy
                                        ? null
                                        : () => _sanction(context, cubit),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: palette.accent2),
                                    child: const Text('SUSPEND / BAN'),
                                  ),
                                ],
                              ],
                            ),
                          ] else if (target.type == ReportTargetType.post)
                            OutlinedButton.icon(
                              onPressed: state.isBusy
                                  ? null
                                  : () async {
                                      final reason = await AppDialogs.reason(
                                        context,
                                        title: 'Restore post',
                                        hint: 'Reason (optional)',
                                        confirmLabel: 'RESTORE',
                                        isRequired: false,
                                      );
                                      if (reason != null) {
                                        await cubit.restorePost(
                                            reason.isEmpty ? null : reason);
                                      }
                                    },
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('RESTORE POST'),
                            ),
                          if (state.isBusy)
                            const Padding(
                              padding: EdgeInsets.only(top: AppSpacing.md),
                              child: LinearProgressIndicator(),
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          Text('${state.reports.length} REPORT(S)',
                              style: AppTypography.mono(
                                  size: 10,
                                  color: palette.muted,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: AppSpacing.sm),
                          ...state.reports.map((r) => Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: palette.border)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(r.reason.label,
                                            style: theme.textTheme.titleSmall),
                                        const SizedBox(width: AppSpacing.sm),
                                        ReportStatusChip(status: r.status),
                                        const Spacer(),
                                        Text(r.createdAt.timeAgo,
                                            style: AppTypography.mono(
                                                size: 9,
                                                color: palette.muted)),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      'by @${r.reporter?.username ?? 'deleted user'}',
                                      style: AppTypography.mono(
                                          size: 9, color: palette.muted),
                                    ),
                                    if ((r.details ?? '').isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(r.details!,
                                          style: theme.textTheme.bodySmall),
                                    ],
                                    if (r.resolutionNote != null) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '${r.resolutionAction ?? 'resolved'}: ${r.resolutionNote}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: palette.muted),
                                      ),
                                    ],
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});
  final ReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final lines = snapshot.context;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CONTENT AT TIME OF REPORT',
              style: AppTypography.mono(
                  size: 9, color: palette.muted, letterSpacing: 1.5)),
          const SizedBox(height: AppSpacing.sm),
          if (lines.isNotEmpty) ...[
            ...lines.reversed.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Text(
                    '${m['body'] ?? '—'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: palette.muted),
                  ),
                )),
            const Divider(),
          ],
          Text(snapshot.text ?? '(content unavailable)',
              style: theme.textTheme.bodyMedium),
          if (snapshot.mediaUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: CachedNetworkImage(
                imageUrl: snapshot.mediaUrl!,
                height: 200,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(Icons.broken_image_outlined, color: palette.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
