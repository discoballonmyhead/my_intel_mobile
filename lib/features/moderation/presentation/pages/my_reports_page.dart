import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../cubits/my_reports_cubit.dart';
import '../widgets/report_labels.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: softAppBar(context, 'My reports'),
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
            return const Center(
              child: SoftMessage(
                icon: Icons.flag_outlined,
                title: 'You haven\u2019t reported anything',
                body: 'Posts you report show up here with what happened to them.',
              ),
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
                      style: inter(13, color: palette.muted),
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
