import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../cubits/my_reports_cubit.dart';
import '../widgets/report_labels.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MY REPORTS')),
      body: BlocBuilder<MyReportsCubit, MyReportsState>(
        builder: (context, state) {
          final cubit = context.read<MyReportsCubit>();
          final palette = context.palette;

          if (state.isLoading) return const AppLoader();
          if (state.failure != null && state.reports.isEmpty) {
            return AppErrorView(
              failure: state.failure ?? const UnexpectedFailure(),
              onRetry: cubit.load,
            );
          }
          if (state.reports.isEmpty) {
            return const AppEmptyView(
              message: 'You have not reported anything',
              icon: Icons.flag_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ContentColumn(
              padded: false,
              child: ListView.separated(
                itemCount: state.reports.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: palette.border),
                itemBuilder: (context, index) {
                  final r = state.reports[index];
                  return ListTile(
                    leading: Icon(reportTargetIcon(r.targetType),
                        color: palette.muted),
                    title: Text('${r.targetType.label} · ${r.reason.label}'),
                    subtitle: Text(
                      r.resolvedAt == null
                          ? 'Reported ${r.createdAt.timeAgo}'
                          : 'Closed ${r.resolvedAt!.timeAgo}',
                      style: AppTypography.mono(size: 9, color: palette.muted),
                    ),
                    trailing: ReportStatusChip(status: r.status),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
