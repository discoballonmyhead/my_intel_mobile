import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// How sure we are about a story, in three steps the reader can feel at a
/// glance: green is high, amber is medium, grey is low.
enum ConfidenceLevel {
  high('High confidence'),
  medium('Medium confidence'),
  low('Low confidence');

  const ConfidenceLevel(this.label);
  final String label;

  static ConfidenceLevel of(int confidence) => confidence >= 70
      ? high
      : confidence >= 55
          ? medium
          : low;

  Color color(AppPalette palette) => switch (this) {
        high => palette.verified,
        medium => palette.warn,
        low => palette.muted,
      };
}

/// Small ring that fills to [confidence]% with the number inside.
class ConfidenceRing extends StatelessWidget {
  const ConfidenceRing({
    required this.confidence,
    this.size = 32,
    super.key,
  });

  final int confidence;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = confidence.clamp(0, 100);
    final level = ConfidenceLevel.of(value);

    return Semantics(
      label: '${level.label}, $value percent',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: value / 100,
            color: level.color(palette),
            track: palette.border,
            stroke: size * 0.09,
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, paint);
    if (fraction <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0, 1),
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
