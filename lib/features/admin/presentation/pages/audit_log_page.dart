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
import '../cubits/audit_log_cubit.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<AuditLogCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuditLogCubit, AuditLogState>(
      builder: (context, state) {
        final cubit = context.read<AuditLogCubit>();
        final palette = context.palette;

        return Scaffold(
          appBar: AppBar(
            title: const Text('AUDIT LOG'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Filter',
                icon: Icon(Icons.filter_list_rounded,
                    color: state.action == null ? null : palette.accent),
                onSelected: (v) => cubit.load(action: v == 'all' ? null : v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'all', child: Text('All actions')),
                  ...AuditLogCubit.knownActions.map((a) => PopupMenuItem(
                        value: a,
                        child: Text(a.replaceAll('_', ' ')),
                      )),
                ],
              ),
            ],
          ),
          body: state.isLoading
              ? const AppLoader()
              : state.failure != null && state.entries.isEmpty
                  ? AppErrorView(
                      failure: state.failure ?? const UnexpectedFailure(),
                      onRetry: () => cubit.load(action: state.action),
                    )
                  : state.entries.isEmpty
                      ? const AppEmptyView(message: 'Nothing logged yet')
                      : RefreshIndicator(
                          onRefresh: () => cubit.load(action: state.action),
                          child: ContentColumn(
                            padded: false,
                            child: ListView.separated(
                              controller: _scroll,
                              itemCount: state.entries.length +
                                  (state.isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: palette.border),
                              itemBuilder: (context, index) {
                                if (index >= state.entries.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: AppLoader(),
                                  );
                                }
                                final e = state.entries[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg),
                                  title: Text(e.actionLabel,
                                      style: AppTypography.mono(size: 10)),
                                  subtitle: Text(
                                    '${e.actor?.username ?? 'system'} → '
                                    '${e.targetType} ${e.targetId.length > 12 ? '${e.targetId.substring(0, 8)}…' : e.targetId}'
                                    '${e.reason == null ? '' : '\n${e.reason}'}',
                                  ),
                                  trailing: Text(e.createdAt.timeAgo,
                                      style: AppTypography.mono(
                                          size: 9, color: palette.muted)),
                                );
                              },
                            ),
                          ),
                        ),
        );
      },
    );
  }
}
