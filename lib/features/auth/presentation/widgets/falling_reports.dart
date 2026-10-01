import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'mint_logo.dart';
import 'radar_backdrop.dart';

/// The sign-in hero: intel report cards keep falling onto a pile over a faint
/// radar, with the MINT card resting on top. Everything is anchored to the
/// bottom of the available space, so when the form below grows (Create
/// account) or the keyboard opens, the pile simply rides up and gets clipped.
///
/// The auth layout wraps the stage in a slot that reports a fixed intrinsic
/// height, so a LayoutBuilder in here is safe under IntrinsicHeight.
class AuthStage extends StatefulWidget {
  const AuthStage({super.key});

  @override
  State<AuthStage> createState() => _AuthStageState();
}

class _CardSpec {
  const _CardSpec(this.tag, this.dx, this.top, this.rotation, this.bars);
  final _Tag tag;
  final double dx; // horizontal offset of the card centre from the stage centre
  final double top; // card top relative to the MINT card's top
  final double rotation; // resting angle in degrees
  final List<double> bars;
}

enum _Tag { breaking, developing, verified, sourced }

class _AuthStageState extends State<AuthStage> with TickerProviderStateMixin {
  static const _cycle = Duration(seconds: 12);
  static const _mintCardHeight = 180.0;
  static const _reportHeight = 124.0;
  static const _bottomGap = 12.0;
  static const _radarDiameter = 380.0;

  static const _cards = [
    _CardSpec(_Tag.breaking, -32, -42, -11, [190, 150, 170]),
    _CardSpec(_Tag.verified, 38, -56, 9, [200, 130, 180]),
    _CardSpec(_Tag.developing, -8, -2, -4, [170, 190, 120]),
    _CardSpec(_Tag.sourced, 24, -20, 13, [180, 140, 160]),
    _CardSpec(_Tag.breaking, -22, -60, 4, [200, 160, 110]),
    _CardSpec(_Tag.verified, 46, 8, -8, [150, 190, 130]),
  ];

  late final AnimationController _rain =
      AnimationController(vsync: this, duration: _cycle);
  late final AnimationController _drop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _rain.stop();
      _float.stop();
      _drop.value = 1;
    } else {
      if (!_rain.isAnimating) _rain.repeat();
      if (!_float.isAnimating) _float.repeat();
      if (_drop.value == 0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _drop.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _rain.dispose();
    _drop.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Top of the MINT card, measured up from the stage bottom.
    const mintTop = _bottomGap + _mintCardHeight;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Radar sits just above the pile and rises into any free space
          // above it, so taller phones don't leave it buried behind the cards.
          LayoutBuilder(
            builder: (context, constraints) {
              const radius = _radarDiameter / 2;
              const pileTop = mintTop + 68; // highest resting card, from the bottom
              final free = math.max(0.0, constraints.maxHeight - pileTop);
              final centreFromBottom = pileTop - 10 + free * 0.35;
              return Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, radius - centreFromBottom),
                  child: const RadarBackdrop(diameter: _radarDiameter),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _rain,
            builder: (context, _) {
              final poses = <(double, Widget)>[];
              for (var i = 0; i < _cards.length; i++) {
                final spec = _cards[i];
                final phase = _still
                    ? (i < 4 ? 0.5 : 0.95)
                    : (_rain.value + i / _cards.length) % 1;
                final pose = _pose(phase, spec.rotation);
                if (pose.opacity <= 0) continue;
                poses.add((
                  phase,
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(
                        spec.dx,
                        spec.top - mintTop + _reportHeight + pose.dy,
                      ),
                      child: Transform.rotate(
                        angle: pose.rotation * math.pi / 180,
                        child: Opacity(
                          opacity: pose.opacity,
                          child: _ReportCard(tag: spec.tag, bars: spec.bars),
                        ),
                      ),
                    ),
                  ),
                ));
              }
              // Most recently dropped card on top.
              poses.sort((a, b) => b.$1.compareTo(a.$1));
              return Stack(
                fit: StackFit.expand,
                children: [for (final p in poses) p.$2],
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, _bottomGap),
              child: AnimatedBuilder(
                animation: Listenable.merge([_drop, _float]),
                builder: (context, child) {
                  final drop = _dropPose(_drop.value);
                  final bob =
                      -5 * (0.5 - 0.5 * math.cos(2 * math.pi * _float.value));
                  return Opacity(
                    opacity: drop.opacity,
                    child: Transform.translate(
                      offset: Offset(0, drop.dy + bob),
                      child: Transform.rotate(
                        angle: drop.rotation * math.pi / 180,
                        child: child,
                      ),
                    ),
                  );
                },
                child: _MintCard(blink: _rain),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fall, bounce, rest, then slide away as newer cards land.
  static ({double dy, double rotation, double opacity}) _pose(
      double p, double r) {
    double seg(double from, double to) => ((p - from) / (to - from)).clamp(0, 1);
    if (p < 0.15) {
      final u = seg(0, 0.15);
      return (
        dy: lerpDouble(-560, 10, Curves.easeInQuad.transform(u))!,
        rotation: lerpDouble(r * -4, r * 1.2, Curves.easeOut.transform(u))!,
        opacity: (p / 0.05).clamp(0, 1),
      );
    }
    if (p < 0.19) {
      final u = seg(0.15, 0.19);
      return (
        dy: lerpDouble(10, -4, u)!,
        rotation: lerpDouble(r * 1.2, r, u)!,
        opacity: 1,
      );
    }
    if (p < 0.22) {
      return (dy: lerpDouble(-4, 0, seg(0.19, 0.22))!, rotation: r, opacity: 1);
    }
    if (p < 0.80) return (dy: 0, rotation: r, opacity: 1);
    if (p < 0.92) {
      final u = seg(0.80, 0.92);
      return (
        dy: lerpDouble(0, 46, Curves.easeIn.transform(u))!,
        rotation: lerpDouble(r, r * 1.4, u)!,
        opacity: 1 - u,
      );
    }
    return (dy: 0, rotation: r, opacity: 0);
  }

  static ({double dy, double rotation, double opacity}) _dropPose(double p) {
    double seg(double from, double to) => ((p - from) / (to - from)).clamp(0, 1);
    final opacity = (p / 0.08).clamp(0.0, 1.0);
    if (p < 0.7) {
      final u = Curves.easeInQuad.transform(seg(0, 0.7));
      return (
        dy: lerpDouble(-620, 12, u)!,
        rotation: lerpDouble(-18, -0.5, u)!,
        opacity: opacity,
      );
    }
    if (p < 0.85) {
      final u = seg(0.7, 0.85);
      return (dy: lerpDouble(12, -5, u)!, rotation: lerpDouble(-0.5, -2, u)!, opacity: 1);
    }
    final u = seg(0.85, 1);
    return (dy: lerpDouble(-5, 0, u)!, rotation: lerpDouble(-2, -1.5, u)!, opacity: 1);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.tag, required this.bars});

  final _Tag tag;
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, color) = switch (tag) {
      _Tag.breaking => ('BREAKING', AppColors.regionBreaking),
      _Tag.developing => ('DEVELOPING', const Color(0xFFE0A800)),
      _Tag.verified => ('VERIFIED', palette.verified),
      _Tag.sourced => ('SOURCED', AppColors.regionQuiet),
    };
    final ink = Color.lerp(color, Colors.black, 0.35)!;

    Widget bar(double w, {bool strong = false}) => Container(
          width: w,
          height: 7,
          decoration: BoxDecoration(
            color: strong ? palette.border : palette.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Container(
      width: 246,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(label,
                    style: AppTypography.mono(
                        size: 8, weight: FontWeight.w700, color: ink, letterSpacing: 1)),
              ),
              const Spacer(),
              bar(40),
            ],
          ),
          const SizedBox(height: 9),
          bar(bars[0], strong: true),
          const SizedBox(height: 9),
          bar(bars[1]),
          const SizedBox(height: 9),
          bar(bars[2]),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              bar(56),
            ],
          ),
        ],
      ),
    );
  }
}

/// The front card: logo, a blinking PRIORITY tag and the tagline.
class _MintCard extends StatelessWidget {
  const _MintCard({required this.blink});

  final Animation<double> blink;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 334),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 44,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const MintLogo(height: 50),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: blink,
                        builder: (context, _) {
                          // One blink per second off the 12s rain clock.
                          final on = (blink.value * 12) % 1 < 0.5;
                          return Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: on ? palette.accent : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      Text('PRIORITY',
                          style: AppTypography.mono(
                              size: 8,
                              weight: FontWeight.w700,
                              color: palette.accent,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                text: 'Intelligence that moves faster than the ',
                children: [
                  TextSpan(text: 'news.', style: TextStyle(color: palette.accent)),
                ],
              ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
