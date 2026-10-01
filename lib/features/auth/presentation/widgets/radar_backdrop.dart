import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Faint radar behind the auth screens: rings, degree ticks, a rotating sweep
/// and a few blips pinging in the region colours. Purely decorative, so it is
/// hidden from screen readers and holds still under reduced motion.
class RadarBackdrop extends StatefulWidget {
  const RadarBackdrop({required this.diameter, this.showTicks = true, super.key});

  final double diameter;
  final bool showTicks;

  @override
  State<RadarBackdrop> createState() => _RadarBackdropState();
}

class _RadarBackdropState extends State<RadarBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock
        ..stop()
        ..value = 0.2;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.diameter),
          painter: _RadarPainter(
            clock: _clock,
            accent: palette.accent,
            ink: Theme.of(context).colorScheme.onSurface,
            showTicks: widget.showTicks,
          ),
        ),
      ),
    );
  }
}

class _Blip {
  const _Blip(this.x, this.y, this.color, this.phase);
  final double x; // -1..1 of the radius
  final double y;
  final Color color;
  final double phase;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.clock,
    required this.accent,
    required this.ink,
    required this.showTicks,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final Color accent;
  final Color ink;
  final bool showTicks;

  static const _blips = [
    _Blip(-0.72, -0.58, AppColors.regionBreaking, 0),
    _Blip(0.76, -0.38, AppColors.regionQuiet, 0.35),
    _Blip(0.6, 0.72, Color(0xFFE0A800), 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = clock.value;

    Paint ring(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: alpha);

    // Rings: the two middle ones breathe slightly out of step.
    final breathe = 0.5 + 0.5 * math.sin(2 * math.pi * t);
    canvas.drawCircle(c, r, ring(0.22));
    canvas.drawCircle(c, r * 0.75, ring(0.12 + 0.08 * breathe));
    canvas.drawCircle(c, r * 0.5, ring(0.12 + 0.08 * (1 - breathe)));
    canvas.drawCircle(c, r * 0.24, ring(0.18));

    // Cross hairs.
    final hair = Paint()
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.1);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), hair);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), hair);

    // Degree ticks every 5 degrees, longer every 30.
    if (showTicks) {
      final minor = Paint()
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.16);
      final major = Paint()
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.45);
      for (var i = 0; i < 72; i++) {
        final a = i * 5 * math.pi / 180;
        final isMajor = i % 6 == 0;
        final len = isMajor ? 10.0 : 5.0;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * r, c + dir * (r - len), isMajor ? major : minor);
      }
    }

    // Sweep: a fading wedge trailing a bright leading edge.
    final angle = 2 * math.pi * t - math.pi / 2;
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [accent.withValues(alpha: 0), accent.withValues(alpha: 0.16)],
        stops: const [0.8, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, sweep);
    canvas.drawLine(
      c,
      c + Offset(math.cos(angle), math.sin(angle)) * r,
      Paint()
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.5),
    );

    // Blips with an expanding ping.
    for (final b in _blips) {
      final p = c + Offset(b.x, b.y) * r;
      final ping = ((t * 2.5) + b.phase) % 1;
      canvas.drawCircle(
        p,
        4 + 14 * ping,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = b.color.withValues(alpha: 0.8 * (1 - ping)),
      );
      canvas.drawCircle(p, 3.5, Paint()..color = b.color);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.accent != accent || old.ink != ink || old.showTicks != showTicks;
}
