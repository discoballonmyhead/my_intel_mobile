import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The MINT wordmark with its signal icon, drawn as vectors so it stays sharp
/// at any size. Geometry is traced from the web app's `logo-light.png`
/// (617 x 309). The signal arcs pulse unless the platform asks for reduced
/// motion.
class MintLogo extends StatefulWidget {
  const MintLogo({this.height = 56, this.color, this.animate = true, super.key});

  final double height;

  /// Defaults to the theme accent (red in Ghost, cyan in Void).
  final Color? color;
  final bool animate;

  static const double aspectRatio = 617 / 309;

  @override
  State<MintLogo> createState() => _MintLogoState();
}

class _MintLogoState extends State<MintLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = !widget.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _pulse.value = 0.5;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accent;
    return Semantics(
      label: 'MINT',
      image: true,
      child: SizedBox(
        height: widget.height,
        width: widget.height * MintLogo.aspectRatio,
        child: CustomPaint(
          painter: _MintLogoPainter(color: color, pulse: _pulse),
        ),
      ),
    );
  }
}

class _MintLogoPainter extends CustomPainter {
  _MintLogoPainter({required this.color, required this.pulse})
      : super(repaint: pulse);

  final Color color;
  final Animation<double> pulse;

  static final Path _letters = _buildLetters();
  static final Path _disc = _buildDisc();

  static Path _poly(List<double> xy) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    return p..close();
  }

  static Path _buildLetters() => Path()
    // M
    ..addPath(
        _poly([1, 309, 1, 134, 51, 134, 99.5, 254, 148, 134, 198, 134, 198, 309,
            156, 309, 156, 218, 120, 309, 79, 309, 42, 218, 42, 309]),
        Offset.zero)
    // I
    ..addRect(const Rect.fromLTWH(230, 134, 42, 175))
    // N
    ..addPath(
        _poly([303, 309, 303, 134, 346, 134, 417, 243, 417, 134, 459, 134, 459,
            309, 417, 309, 345, 200, 345, 309]),
        Offset.zero)
    // T
    ..addPath(
        _poly([482, 134, 617, 134, 617, 176, 570, 176, 570, 309, 528, 309, 528,
            176, 482, 176]),
        Offset.zero);

  // Disc with a cut-out ring: outer fill, ring hole, centre dot.
  static Path _buildDisc() => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: const Offset(251, 50), radius: 48))
    ..addOval(Rect.fromCircle(center: const Offset(251, 50), radius: 24))
    ..addOval(Rect.fromCircle(center: const Offset(251, 50), radius: 13.5));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 617, size.height / 309);

    final fill = Paint()..color = color;
    canvas.drawPath(_letters, fill);
    canvas.drawPath(_disc, fill);

    // Inner arcs pulse; the outer pair echoes them half a beat later.
    final t = pulse.value;
    double wave(double phase) =>
        0.15 + 0.85 * (0.5 - 0.5 * math.cos(2 * math.pi * ((t + phase) % 1)));
    _arcs(canvas, 66, 54, color.withValues(alpha: wave(0)));
    _arcs(canvas, 88, 57, color.withValues(alpha: wave(0.75) * 0.8));
    canvas.restore();
  }

  void _arcs(Canvas canvas, double radius, double sweepDeg, Color c) {
    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: const Offset(251, 51), radius: radius);
    final sweep = sweepDeg * math.pi / 180;
    canvas.drawArc(rect, math.pi - sweep / 2, sweep, false, paint);
    canvas.drawArc(rect, -sweep / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_MintLogoPainter old) => old.color != color;
}
