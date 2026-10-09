import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/toggle_follow.dart';
import '../providers/profile_cubit.dart';
import '../widgets/profile_ui.dart';

/// The signed-in user's followers and the people they follow, as two tabs.
class FollowListPage extends StatefulWidget {
  const FollowListPage({this.showFollowing = false, super.key});

  final bool showFollowing;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  late bool _following = widget.showFollowing;
  List<Profile>? _followers;
  List<Profile>? _followed;
  Set<String> _iFollow = {};
  final _busy = <String>{};
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final userId = context.read<ProfileCubit>().state.profile?.id;
    if (userId == null) return;
    setState(() => _failed = false);
    final (followers, following, ids) = await (
      sl<GetFollowList>()(FollowListParams(userId, followers: true)),
      sl<GetFollowList>()(FollowListParams(userId, followers: false)),
      sl<GetFollowedUserIds>()(const NoParams()),
    ).wait;
    if (!mounted) return;
    setState(() {
      _followers = followers.valueOrNull;
      _followed = following.valueOrNull;
      _iFollow = {...?ids.valueOrNull};
      _failed = followers.failureOrNull != null || following.failureOrNull != null;
    });
  }

  Future<void> _toggle(Profile person) async {
    if (_busy.contains(person.id)) return;
    final wasFollowing = _iFollow.contains(person.id);
    setState(() {
      _busy.add(person.id);
      wasFollowing ? _iFollow.remove(person.id) : _iFollow.add(person.id);
    });
    final result = await sl<ToggleFollow>()(person.id);
    if (!mounted) return;
    setState(() {
      _busy.remove(person.id);
      if (result.failureOrNull != null) {
        wasFollowing ? _iFollow.add(person.id) : _iFollow.remove(person.id);
      }
    });
    unawaited(context.read<ProfileCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final username = context.select<ProfileCubit, String>(
        (c) => c.state.profile?.username ?? 'Profile');
    final list = _following ? _followed : _followers;

    return Scaffold(
      appBar: softAppBar(context, username),
      body: Column(
        children: [
          _Tabs(
            following: _following,
            followers: _followers?.length,
            followed: _followed?.length,
            onChanged: (v) => setState(() => _following = v),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: list == null
                  ? (_failed
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          SoftMessage(
                            icon: Icons.wifi_off_rounded,
                            title: 'Can’t load this list',
                            body: 'Check your connection and try again.',
                            action: 'Try again',
                            onAction: _load,
                          ),
                        ])
                      : const Center(child: CircularProgressIndicator()))
                  : list.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          _following
                              ? SoftMessage(
                                  icon: Icons.person_add_alt_rounded,
                                  title: 'Not following anyone yet',
                                  body:
                                      'Follow people to see their posts in your Feed.',
                                  action: 'Find people',
                                  filledAction: true,
                                  onAction: () => context.push(AppRoutes.search),
                                )
                              : const SoftMessage(
                                  icon: Icons.group_outlined,
                                  title: 'No followers yet',
                                  body:
                                      'When people follow you, they’ll show up here.',
                                ),
                        ])
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 6, bottom: 32),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _PersonRow(
                            person: list[i],
                            following: _iFollow.contains(list[i].id),
                            busy: _busy.contains(list[i].id),
                            followBackLabel: !_following,
                            onToggle: () => _toggle(list[i]),
                            onOpen: () =>
                                context.push(AppRoutes.channelFor(list[i].username)),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.following,
    required this.followers,
    required this.followed,
    required this.onChanged,
  });

  final bool following;
  final int? followers;
  final int? followed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget tab(String label, int? count, bool value) {
      final on = following == value;
      final text = count == null ? label : '$count  $label';
      return Expanded(
        child: InkWell(
          onTap: on ? null : () => onChanged(value),
          child: SizedBox(
            height: 46,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(text,
                    style: inter(15,
                        weight: on ? FontWeight.w600 : FontWeight.w400,
                        color: on ? onSurface : palette.muted)),
                const SizedBox(height: 10),
                Container(height: 2, width: on ? text.length * 8.0 + 8 : 0, color: onSurface),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(children: [
        tab('Followers', followers, false),
        tab('Following', followed, true),
      ]),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.following,
    required this.busy,
    required this.followBackLabel,
    required this.onToggle,
    required this.onOpen,
  });

  final Profile person;
  final bool following;
  final bool busy;
  final bool followBackLabel;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final initial = person.username.isEmpty ? '?' : person.username[0].toUpperCase();
    final label = following ? 'Following' : (followBackLabel ? 'Follow back' : 'Follow');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: palette.surface2, shape: BoxShape.circle),
              child: Text(initial,
                  style: inter(18, weight: FontWeight.w600, color: palette.accent)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: inter(16, weight: FontWeight.w600, color: onSurface)),
                  const SizedBox(height: 2),
                  Text(person.role.displayName, style: inter(13, color: palette.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PillButton(
              label: label,
              onPressed: onToggle,
              soft: following,
              loading: busy,
              height: 34,
              width: following ? 104 : 116,
            ),
          ],
        ),
      ),
    );
  }
}
