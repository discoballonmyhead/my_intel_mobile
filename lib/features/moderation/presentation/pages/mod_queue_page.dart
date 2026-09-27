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
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/report.dart';
import '../cubits/mod_queue_cubit.dart';
import '../widgets/report_labels.dart';

class ModQueuePage extends StatelessWidget {
  const ModQueuePage({super.key});

  static const _statuses = [
    ReportStatus.open,
    ReportStatus.actioned,
    ReportStatus.dismissed,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModQueueCubit, ModQueueState>(
      builder: (context, state) {
        final cubit = context.read<ModQueueCubit>();
        final palette = context.palette;

        return Scaffold(
          appBar: AppBar(
            title: const Text('REPORTS'),
            actions: [
              // PopupMenuButton ignores null values, so "all" is a sentinel.
              PopupMenuButton<String>(
                tooltip: 'Filter by type',
                icon: Icon(Icons.filter_list_rounded,
                    color: state.targetType == null ? null : palette.accent),
                onSelected: (value) => cubit.setTargetType(
                    value == 'all' ? null : ReportTargetType.fromValue(value)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text('All types')),
                  ...ReportTargetType.values.map((t) =>
                      PopupMenuItem(value: t.value, child: Text(t.label))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: SegmentedButton<ReportStatus>(
                  segments: _statuses
                      .map((s) => ButtonSegment(
                            value: s,
                            label: Text(s == ReportStatus.open ? 'OPEN' : s.label),
                          ))
                      .toList(),
                  selected: {state.status},
                  onSelectionChanged: (s) => cubit.setStatus(s.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.load(silent: true),
                  child: state.isLoading
                      ? const AppLoader(label: 'Loading reports')
                      : state.failure != null && state.items.isEmpty
                          ? AppErrorView(
                              failure: state.failure ?? const UnexpectedFailure(),
                              onRetry: cubit.load,
                            )
                          : state.items.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 120),
                                    AppEmptyView(
                                      message: 'Queue is clear',
                                      icon: Icons.verified_user_outlined,
                                    ),
                                  ],
                                )
                              : ContentColumn(
                                  padded: false,
                                  child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: state.items.length,
                                    itemBuilder: (context, index) {
                                      final item = state.items[index];
                                      return _QueueTile(
                                        item: item,
                                        onTap: () async {
                                          await context.push(
                                              AppRoutes.adminReportFor(
                                                  item.targetType.value,
                                                  item.targetId));
                                          if (context.mounted) {
                                            cubit.load(silent: true);
                                          }
                                        },
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

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.item, required this.onTap});

  final ReportQueueItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final severe = item.reporterCount >= 5;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(reportTargetIcon(item.targetType), color: palette.muted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${item.targetType.label.toUpperCase()} · '
                        '${item.reporterCount} REPORTER${item.reporterCount == 1 ? '' : 'S'}',
                        style: AppTypography.mono(
                            size: 9,
                            color: severe ? palette.accent2 : palette.warn),
                      ),
                      const Spacer(),
                      Text(item.lastReportedAt.timeAgo,
                          style:
                              AppTypography.mono(size: 9, color: palette.muted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.snapshot.text ?? '(no preview)',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ...item.reasons.map((r) => Chip(
                            label: Text(r.label),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      'by @${item.owner?.username ?? 'unknown'}',
                      if (item.ownerPriorSanctions > 0)
                        '${item.ownerPriorSanctions} prior sanction(s)',
                      if (item.assignedTo != null) 'claimed',
                    ].join(' · '),
                    style: AppTypography.mono(size: 9, color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
