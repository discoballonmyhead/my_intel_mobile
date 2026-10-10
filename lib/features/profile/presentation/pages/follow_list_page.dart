import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../cubits/follow_list_cubit.dart';

class FollowListPage extends StatefulWidget {
  const FollowListPage({this.title, super.key});

  /// e.g. "@alice" — shown above the list.
  final String? title;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        context.read<FollowListCubit>().loadMore();
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
    final myId = context.select<AuthCubit, String?>((c) => c.state.user?.id);

    return BlocConsumer<FollowListCubit, FollowListState>(
      listenWhen: (a, b) =>
          b.actionFailure != null && a.actionFailure != b.actionFailure,
      listener: (context, state) {
        AppDialogs.snack(context, state.actionFailure!.message);
        context.read<FollowListCubit>().clearActionFailure();
      },
      builder: (context, state) {
        final cubit = context.read<FollowListCubit>();
        final palette = context.palette;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title == null
                ? state.kind.label
                : '${widget.title} · ${state.kind.label}'),
          ),
          body: state.isLoading
              ? const AppLoader()
              : state.failure != null
                  ? AppErrorView(
                      failure: state.failure ?? const UnexpectedFailure(),
                      onRetry: cubit.load,
                    )
                  : state.entries.isEmpty
                      ? AppEmptyView(
                          message: state.kind.value == 'followers'
                              ? 'No followers yet'
                              : 'Not following anyone yet',
                          icon: Icons.people_outline_rounded,
                        )
                      : ContentColumn(
                          padded: false,
                          child: ListView.builder(
                            controller: _scroll,
                            itemCount: state.entries.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= state.entries.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  child: AppLoader(),
                                );
                              }
                              final entry = state.entries[index];
                              final p = entry.profile;
                              final isMe = p.id == myId;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg),
                                leading: UserAvatar(name: p.username),
                                title: Text(p.username),
                                subtitle: Align(
                                  alignment: Alignment.centerLeft,
                                  child: RoleBadge(role: p.role),
                                ),
                                onTap: () =>
                                    context.push(AppRoutes.channelFor(p.username)),
                                trailing: isMe
                                    ? null
                                    : SizedBox(
                                        width: 112,
                                        child: entry.isFollowing
                                            ? OutlinedButton(
                                                onPressed: state.busyIds
                                                        .contains(p.id)
                                                    ? null
                                                    : () => cubit.toggle(entry),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: palette.muted,
                                                ),
                                                child: const Text('FOLLOWING'),
                                              )
                                            : FilledButton(
                                                onPressed: state.busyIds
                                                        .contains(p.id)
                                                    ? null
                                                    : () => cubit.toggle(entry),
                                                child: const Text('FOLLOW'),
                                              ),
                                      ),
                              );
                            },
                          ),
                        ),
        );
      },
    );
  }
}
