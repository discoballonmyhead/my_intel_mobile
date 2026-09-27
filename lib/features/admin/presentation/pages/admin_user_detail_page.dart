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
import '../../../../core/widgets/user_avatar.dart';
import '../../../account/domain/entities/user_access.dart';
import '../../../account/presentation/cubits/access_cubit.dart';
import '../../../moderation/presentation/widgets/report_labels.dart';
import '../../domain/entities/admin_entities.dart';
import '../cubits/admin_user_detail_cubit.dart';
import '../widgets/ban_user_dialog.dart';

class AdminUserDetailPage extends StatelessWidget {
  const AdminUserDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminUserDetailCubit, AdminUserDetailState>(
      listenWhen: (a, b) =>
          (b.message != null && a.message != b.message) ||
          (b.actionFailure != null && a.actionFailure != b.actionFailure),
      listener: (context, state) {
        final text = state.actionFailure?.message ?? state.message;
        if (text != null) AppDialogs.snack(context, text);
        context.read<AdminUserDetailCubit>().clearFeedback();
        if (state.isDeleted && context.canPop()) context.pop(true);
      },
      builder: (context, state) {
        final cubit = context.read<AdminUserDetailCubit>();
        final detail = state.detail;

        return Scaffold(
          appBar: AppBar(
            title: Text(detail?.user.displayName.toUpperCase() ?? 'USER'),
          ),
          body: state.isLoading
              ? const AppLoader()
              : detail == null
                  ? AppErrorView(
                      failure: state.failure ?? const NotFoundFailure(),
                      onRetry: cubit.load,
                    )
                  : RefreshIndicator(
                      onRefresh: cubit.load,
                      child: ContentColumn(
                        child: _DetailBody(detail: detail, busy: state.isBusy),
                      ),
                    ),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.busy});

  final AdminUserDetail detail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminUserDetailCubit>();
    final me = context.watch<AccessCubit>().state.access;
    final palette = context.palette;
    final theme = Theme.of(context);
    final user = detail.user;
    final outranked = me.rank > user.rank || me.isSuperAdmin;
    final handle = '@${user.displayName}';

    Future<void> ban() async {
      final request = await BanUserDialog.show(
        context,
        username: handle,
        allowPermanent: me.isAdmin,
      );
      if (request == null) return;
      await cubit.ban(
        reason: request.reason,
        duration: request.duration,
        hideContent: request.hideContent,
      );
    }

    Future<void> toggleRole(AppRole role, bool grant) async {
      if (grant) {
        await cubit.grantRole(role);
        return;
      }
      final reason = await AppDialogs.reason(
        context,
        title: 'Remove ${role.label}',
        hint: 'Reason',
        confirmLabel: 'REMOVE',
        isRequired: role == AppRole.osint,
        destructive: true,
      );
      if (reason == null) return;
      if (role == AppRole.osint) {
        await cubit.revokeOsint(reason);
      } else {
        await cubit.revokeRole(role, reason: reason.isEmpty ? null : reason);
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        Row(
          children: [
            UserAvatar(name: user.displayName, radius: 28),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: theme.textTheme.titleLarge),
                  if (user.email != null)
                    Text(user.email!,
                        style: AppTypography.mono(size: 10, color: palette.muted)),
                  if (user.createdAt != null)
                    Text('Joined ${user.createdAt!.absolute}',
                        style: AppTypography.mono(size: 9, color: palette.muted)),
                  if (user.lastSignInAt != null)
                    Text('Last seen ${user.lastSignInAt!.timeAgo}',
                        style: AppTypography.mono(size: 9, color: palette.muted)),
                ],
              ),
            ),
            if (user.profile != null)
              IconButton(
                tooltip: 'Open channel',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () =>
                    context.push(AppRoutes.channelFor(user.profile!.username)),
              ),
          ],
        ),
        if (user.isBanned) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.accent2.withValues(alpha: 0.08),
              border: Border.all(color: palette.accent2.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              user.bannedUntil == null
                  ? 'BANNED PERMANENTLY'
                  : 'SUSPENDED UNTIL ${user.bannedUntil!.absolute.toUpperCase()}',
              style: AppTypography.mono(size: 10, color: palette.accent2),
            ),
          ),
        ],
        if (busy) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Label('ACTIONS'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton(
              onPressed: busy || !outranked
                  ? null
                  : () async {
                      final reason = await AppDialogs.reason(context,
                          title: 'Warn $handle',
                          hint: 'Reason (shown to the user)',
                          confirmLabel: 'WARN');
                      if (reason != null) await cubit.warn(reason);
                    },
              style: OutlinedButton.styleFrom(foregroundColor: palette.warn),
              child: const Text('WARN'),
            ),
            if (!user.isBanned)
              FilledButton(
                onPressed: busy || !outranked ? null : ban,
                style: FilledButton.styleFrom(backgroundColor: palette.accent2),
                child: const Text('SUSPEND / BAN'),
              )
            else
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final reason = await AppDialogs.reason(context,
                            title: 'Lift ban',
                            hint: 'Reason (optional)',
                            confirmLabel: 'UNBAN',
                            isRequired: false);
                        if (reason != null) {
                          await cubit.unban(
                              reason: reason.isEmpty ? null : reason);
                        }
                      },
                child: const Text('UNBAN'),
              ),
            if (me.isAdmin)
              OutlinedButton(
                onPressed: busy || !outranked
                    ? null
                    : () async {
                        final reason = await AppDialogs.reason(
                          context,
                          title: 'Delete $handle permanently?',
                          hint: 'Reason (required, logged)',
                          confirmLabel: 'DELETE ACCOUNT',
                          destructive: true,
                        );
                        if (reason == null || !context.mounted) return;
                        final sure = await AppDialogs.confirm(
                          context,
                          title: 'This cannot be undone',
                          message:
                              'Their profile, posts and interactions are erased. '
                              'Messages become "deleted user" placeholders.',
                          confirmLabel: 'DELETE',
                          destructive: true,
                        );
                        if (sure) await cubit.deleteAccount(reason);
                      },
                style: OutlinedButton.styleFrom(foregroundColor: palette.accent2),
                child: const Text('DELETE ACCOUNT'),
              ),
          ],
        ),
        if (me.isAdmin) ...[
          const SizedBox(height: AppSpacing.xl),
          _Label('ROLES'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: AppRole.values.map((role) {
              final has = detail.hasRole(role);
              // Only a super admin hands out admin-level roles.
              final allowed = role.rank < 2 || me.isSuperAdmin;
              return FilterChip(
                label: Text(role.label),
                selected: has,
                onSelected: busy || !allowed
                    ? null
                    : (selected) => toggleRole(role, selected),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Label('SANCTIONS (${detail.sanctions.length})'),
        if (detail.sanctions.isEmpty)
          Text('None', style: theme.textTheme.bodySmall)
        else
          ...detail.sanctions.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${s.kind.label}${s.isActive ? '' : ' (inactive)'}',
                  style: AppTypography.mono(
                    size: 10,
                    color: s.isActive ? palette.accent2 : palette.muted,
                  ),
                ),
                subtitle: Text(
                  '${s.reason}\n${s.createdAt.absolute}'
                  '${s.expiresAt == null ? '' : ' → ${s.expiresAt!.absolute}'}'
                  '${s.liftReason == null ? '' : '\nLifted: ${s.liftReason}'}',
                ),
                isThreeLine: true,
                trailing: s.isActive && s.kind != SanctionKind.osintRevoked
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final reason = await AppDialogs.reason(context,
                                    title: 'Lift ${s.kind.label.toLowerCase()}',
                                    hint: 'Reason (optional)',
                                    confirmLabel: 'LIFT',
                                    isRequired: false);
                                if (reason != null) {
                                  await cubit.liftSanction(s.id,
                                      reason: reason.isEmpty ? null : reason);
                                }
                              },
                        child: const Text('LIFT'),
                      )
                    : null,
              )),
        const SizedBox(height: AppSpacing.xl),
        _Label('REPORTS AGAINST (${detail.reportsAgainst.length}) · '
            'FILED ${detail.reportsFiled}'),
        if (detail.reportsAgainst.isEmpty)
          Text('None', style: theme.textTheme.bodySmall)
        else
          ...detail.reportsAgainst.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(reportTargetIcon(r.targetType), size: 18),
                title: Text('${r.targetType.label} · ${r.reason.label}'),
                subtitle: Text(r.snapshot.text ?? r.createdAt.absolute,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: ReportStatusChip(status: r.status),
                onTap: () => context.push(
                    AppRoutes.adminReportFor(r.targetType.value, r.targetId)),
              )),
        if (detail.osintApplications.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Label('OSINT APPLICATIONS'),
          ...detail.osintApplications.map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${a.channelName} (${a.handle})'),
                subtitle: Text(a.createdAt?.absolute ?? ''),
                trailing: Text(a.status.toUpperCase(),
                    style: AppTypography.mono(size: 9, color: palette.accent)),
              )),
        ],
        if (detail.audit.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Label('HISTORY'),
          ...detail.audit.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.actionLabel,
                    style: AppTypography.mono(size: 10)),
                subtitle: Text(
                    '${e.actor?.username ?? 'system'} · ${e.createdAt.absolute}'
                    '${e.reason == null ? '' : '\n${e.reason}'}'),
              )),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text,
          style: AppTypography.mono(
              size: 10, color: context.palette.muted, letterSpacing: 1.5)),
    );
  }
}
