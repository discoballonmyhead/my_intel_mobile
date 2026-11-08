import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/responsive/responsive_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../profile/presentation/widgets/profile_ui.dart';
import '../../domain/lean.dart';
import '../cubits/lean_cubit.dart';
import '../widgets/compass_view.dart';

/// "Your compass": where your likes put you, and what the feed does with it.
/// Brings its own [LeanCubit], so it works from any route or main.dart.
class CompassPage extends StatelessWidget {
  const CompassPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<LeanCubit>.value(
        value: sl<LeanCubit>(),
        child: const _CompassBody(),
      );
}

class _CompassBody extends StatefulWidget {
  const _CompassBody();

  @override
  State<_CompassBody> createState() => _CompassPageState();
}

class _CompassPageState extends State<_CompassBody> {
  /// The point being dragged in "Pick a spot" mode, before it is saved.
  LeanPoint? _dragging;

  @override
  void initState() {
    super.initState();
    context.read<LeanCubit>().refresh();
  }

  Future<void> _turnOff(LeanCubit cubit) async {
    final ok = await AppDialogs.confirm(
      context,
      title: 'Turn off the compass?',
      message:
          'Your position and its history are deleted, and the feed goes back to normal.',
      confirmLabel: 'TURN OFF',
      destructive: true,
    );
    if (ok && mounted)
      await _report(
          cubit.disable(), 'Compass turned off. Your data was deleted.');
  }

  Future<void> _report(Future<bool> action, String success) async {
    final ok = await action;
    if (!mounted) return;
    final failure = context.read<LeanCubit>().state.failure;
    AppDialogs.snack(context,
        ok ? success : failure?.message ?? 'That didn’t work. Try again.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: softAppBar(context, 'Your compass'),
        body: BlocBuilder<LeanCubit, LeanState>(
          builder: (context, state) {
            final cubit = context.read<LeanCubit>();
            final s = state.status;
            return ContentColumn(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
                children: [
                  if (state.busy) const LinearProgressIndicator(minHeight: 2),
                  if (!state.loaded)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!s.enabled)
                    _OptIn(
                        busy: state.busy,
                        onEnable: () =>
                            _report(cubit.enable(), 'Compass turned on.'))
                  else ...[
                    _CompassCard(
                      status: s,
                      dragging: _dragging,
                      onPick: s.mode == LeanMode.spot
                          ? (p) => setState(() => _dragging = p)
                          : null,
                      onPickEnd: s.mode == LeanMode.spot
                          ? (p) async {
                              await cubit.setSpot(p);
                              if (mounted) setState(() => _dragging = null);
                            }
                          : null,
                    ),
                    const SectionLabel('Feed filter'),
                    SettingsGroup([
                      for (final m in LeanMode.values)
                        SettingsRow(
                          title: _modeTitle(m),
                          subtitle: _modeHint(m, s),
                          checked: s.mode == m,
                          onTap: state.busy || s.mode == m
                              ? null
                              : () => cubit.setMode(m),
                        ),
                    ]),
                    SettingsGroup([
                      SettingsRow(
                        title: 'Reset history',
                        subtitle:
                            'Clears the trail. Your position is worked out again from your likes.',
                        icon: Icons.history_rounded,
                        chevron: false,
                        onTap: state.busy
                            ? null
                            : () => _report(
                                cubit.resetHistory(), 'History cleared.'),
                      ),
                      SettingsRow(
                        title: 'Turn off and delete',
                        icon: Icons.delete_outline_rounded,
                        iconColor: context.palette.accent,
                        titleColor: context.palette.accent,
                        chevron: false,
                        onTap: state.busy ? null : () => _turnOff(cubit),
                      ),
                    ]),
                    const _PrivacyNote(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _modeTitle(LeanMode m) => switch (m) {
        LeanMode.off => 'Off',
        LeanMode.balanced => 'Balanced',
        LeanMode.opposite => 'Other side',
        LeanMode.spot => 'Pick a spot',
      };

  static String _modeHint(LeanMode m, LeanStatus s) => switch (m) {
        LeanMode.off => 'The normal feed',
        LeanMode.balanced => 'The best posts from all four corners take turns',
        LeanMode.opposite => s.hasPosition
            ? 'More posts from the corner opposite to yours'
            : 'Needs a position first: works like Balanced until then',
        LeanMode.spot => 'Tap or drag on the compass to choose where',
      };
}

class _OptIn extends StatelessWidget {
  const _OptIn({required this.busy, required this.onEnable});

  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: palette.muted),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(text,
                      style: inter(15, color: onSurface, height: 1.4))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: AspectRatio(aspectRatio: 1, child: CompassView()),
        ),
        const SizedBox(height: 16),
        Text('See where your likes put you',
            textAlign: TextAlign.center,
            style: inter(20, weight: FontWeight.w700, color: onSurface)),
        const SizedBox(height: 20),
        point(
            Icons.explore_outlined,
            'Our team places posts on two axes: economic left to right, and libertarian to authoritarian. '
            'Your dot is the average of the posts you liked in the last 90 days.'),
        point(Icons.lock_outline_rounded,
            'Only you can see your position. Staff only see totals for groups of 20 or more people, never you.'),
        point(Icons.tune_rounded,
            'You can use it to balance your feed or see the other side. Your feed only changes if you choose a filter.'),
        point(Icons.delete_outline_rounded,
            'Turn it off any time, and your position and history are deleted.'),
        const SizedBox(height: 8),
        PillButton(label: 'Turn on', loading: busy, onPressed: onEnable),
      ],
    );
  }
}

class _CompassCard extends StatelessWidget {
  const _CompassCard(
      {required this.status, this.dragging, this.onPick, this.onPickEnd});

  final LeanStatus status;
  final LeanPoint? dragging;
  final ValueChanged<LeanPoint>? onPick;
  final ValueChanged<LeanPoint>? onPickEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pos = status.hasPosition ? status.position : null;
    final target = status.mode == LeanMode.spot
        ? (dragging ?? status.spot ?? LeanPoint.centre)
        : status.target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AspectRatio(
            aspectRatio: 1,
            child: CompassView(
              position: pos,
              trail: status.hasPosition ? status.trail : const [],
              target: target,
              onPick: onPick,
              onPickEnd: onPickEnd,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(pos == null ? 'No position yet' : pos.describe,
            textAlign: TextAlign.center,
            style: inter(18, weight: FontWeight.w700, color: onSurface)),
        const SizedBox(height: 4),
        Text(
          pos == null
              ? 'Like a few posts and it appears here. Only posts our team has placed on the compass count.'
              : 'From ${status.items} classified like${status.items == 1 ? '' : 's'} · updated when you open the app',
          textAlign: TextAlign.center,
          style: inter(13, color: palette.muted, height: 1.4),
        ),
        if (status.mode == LeanMode.spot) ...[
          const SizedBox(height: 6),
          Text('The ring is where your feed leans. Drag it to move it.',
              textAlign: TextAlign.center,
              style: inter(13, color: palette.muted)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          'Only you can see this. Staff see totals for groups of 20 or more, never one person. '
          'Your position is only worked out while the compass is on.',
          style: inter(12, color: context.palette.muted, height: 1.45),
        ),
      );
}
