import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/role_badge.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/domain/usecases/get_feed.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/toggle_follow.dart';

/// Another user's channel, addressed by username. Composes the use cases it
/// needs directly instead of holding a long-lived provider — the screen is
/// transient and its state does not outlive it.
class ChannelPage extends StatefulWidget {
  const ChannelPage({required this.username, super.key});

  final String username;

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  Profile? _profile;
  FollowStats _stats = const FollowStats();
  List<Post> _posts = const [];
  Failure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final result = await context.read<GetProfileByUsername>()(widget.username);
    if (!mounted) return;

    final profile = result.valueOrNull;
    if (profile == null) {
      setState(() {
        _failure = result.failureOrNull;
        _loading = false;
      });
      return;
    }

    final stats = await context.read<GetFollowStats>()(profile.id);
    final posts = await context.read<GetPostsByAuthor>()(profile.id);
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _stats = stats.valueOrNull ?? const FollowStats();
      _posts = posts.valueOrNull ?? const [];
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null) return;

    // Optimistic, reverted if the write fails.
    final previous = _stats;
    setState(() {
      _stats = _stats.copyWith(
        isFollowing: !_stats.isFollowing,
        followers: _stats.isFollowing
            ? (_stats.followers - 1).clamp(0, 1 << 30)
            : _stats.followers + 1,
      );
    });

    final result = await context.read<ToggleFollow>()(profile.id);
    if (!mounted) return;
    setState(() => _stats = result.valueOrNull ?? previous);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}'.toUpperCase())),
      body: _loading
          ? const AppLoader()
          : profile == null
              ? AppErrorView(
                  failure: _failure ?? const NotFoundFailure(),
                  onRetry: _load,
                )
              : ContentColumn(
                  padded: false,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: palette.surface2,
                                  child: Text(
                                    profile.username.characters.first.toUpperCase(),
                                    style: AppTypography.mono(
                                      size: 17,
                                      color: palette.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.username,
                                        style:
                                            Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      RoleBadge(role: profile.role),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  onPressed: _toggleFollow,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(104, 38),
                                    backgroundColor: _stats.isFollowing
                                        ? palette.surface2
                                        : palette.accent,
                                    foregroundColor: _stats.isFollowing
                                        ? palette.muted
                                        : null,
                                  ),
                                  child: Text(
                                    _stats.isFollowing ? 'FOLLOWING' : 'FOLLOW',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                _Metric(
                                  label: 'FOLLOWERS',
                                  value: _stats.followers,
                                ),
                                _Metric(
                                  label: 'FOLLOWING',
                                  value: _stats.following,
                                ),
                                if (profile.isAnalyst)
                                  _Metric(label: 'CRED', value: profile.score),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: palette.border, height: 1),
                      if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: AppEmptyView(message: 'No posts yet'),
                        )
                      else
                        ..._posts.map((p) => Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: palette.border),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.createdAt.timeAgo,
                                    style: AppTypography.mono(
                                      size: 9,
                                      color: palette.muted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    p.body,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          Text(
            label,
            style: AppTypography.mono(
              size: 9,
              color: context.palette.muted,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
