import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_cubit.dart';
import '../../domain/entities/profile.dart';
import '../cubits/follow_list_cubit.dart';
import '../widgets/profile_ui.dart';

/// Followers of someone, or the people they follow, with a Follow /
/// Following button on each row. The one list page for both your own lists
/// (Profile header) and anyone else's (a channel).
class FollowListPage extends StatefulWidget {
  const FollowListPage({this.title, super.key});

  /// e.g. "@alice", shown before "Followers" / "Following".
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
        final followers = state.kind == FollowListKind.followers;
        final label = followers ? 'Followers' : 'Following';
        final Widget body;
        if (state.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state.failure != null) {
          body = Center(
            child: SoftMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Couldn’t load this list',
              body: state.failure!.message,
              action: 'Try again',
              onAction: cubit.load,
            ),
          );
        } else if (state.entries.isEmpty) {
          body = Center(
            child: SoftMessage(
              icon: Icons.people_outline_rounded,
              title: followers ? 'No followers yet' : 'Not following anyone',
              body: followers
                  ? 'People who follow will show up here.'
                  : 'People followed will show up here.',
            ),
          );
        } else {
          body = ContentColumn(
            padded: false,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.only(top: 6, bottom: 40),
              itemCount: state.entries.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: context.palette.border.withValues(alpha: 0.6),
              ),
              itemBuilder: (context, index) {
                if (index >= state.entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final entry = state.entries[index];
                return _PersonRow(
                  entry: entry,
                  isMe: entry.profile.id == myId,
                  busy: state.busyIds.contains(entry.profile.id),
                  onToggle: () => cubit.toggle(entry),
                );
              },
            ),
          );
        }

        return Scaffold(
          appBar: softAppBar(
            context,
            widget.title == null ? label : '${widget.title} · $label',
          ),
          body: RefreshIndicator(onRefresh: cubit.load, child: body),
        );
      },
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.entry,
    required this.isMe,
    required this.busy,
    required this.onToggle,
  });

  final FollowListEntry entry;
  final bool isMe;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final p = entry.profile;
    return InkWell(
      onTap: () => context.push(AppRoutes.channelFor(p.username)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            UserAvatar(name: p.username, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.username,
                            overflow: TextOverflow.ellipsis,
                            style: inter(16,
                                weight: FontWeight.w600, color: onSurface)),
                      ),
                      const SizedBox(width: 4),
                      RoleBadge(role: p.role, compact: true),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(p.role.displayName,
                      style: inter(13, color: palette.muted)),
                ],
              ),
            ),
            if (!isMe)
              SizedBox(
                height: 36,
                child: entry.isFollowing
                    ? OutlinedButton(
                        onPressed: busy ? null : onToggle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onSurface,
                          side: BorderSide(color: palette.border),
                          shape: const StadiumBorder(),
                          textStyle: inter(14, weight: FontWeight.w600),
                        ),
                        child: const Text('Following'),
                      )
                    : FilledButton(
                        onPressed: busy ? null : onToggle,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          textStyle: inter(14, weight: FontWeight.w600),
                        ),
                        child: const Text('Follow'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
