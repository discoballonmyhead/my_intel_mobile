import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/lean.dart';

/// The two-axis compass: economic left ↔ right across, authoritarian (up)
/// ↔ libertarian (down) top to bottom.
///
/// Shows an optional [position] with its [trail], a [target] ring, and text in
/// each corner ([corners]: up-left, up-right, down-left, down-right). With
/// [onPick] the user (or staff, when classifying) can drag a point.
class CompassView extends StatelessWidget {
  const CompassView({
    this.position,
    this.trail = const [],
    this.target,
    this.corners,
    this.onPick,
    this.onPickEnd,
    this.labels = true,
    this.size,
    super.key,
  });

  final LeanPoint? position;
  final List<LeanPoint> trail;
  final LeanPoint? target;
  final List<String?>? corners;
  final ValueChanged<LeanPoint>? onPick;
  final ValueChanged<LeanPoint>? onPickEnd;
  final bool labels;
  final double? size;

  static const _quadrantColors = [
    Color(0xFFE5484D), // up-left
    Color(0xFF3E63DD), // up-right
    Color(0xFF30A46C), // down-left
    Color(0xFF8E4EC6), // down-right
  ];

  LeanPoint _toPoint(Offset local, double side) =>
      LeanPoint(local.dx / side * 2 - 1, 1 - local.dy / side * 2).clamp();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(builder: (context, constraints) {
      final side = size ??
          math.min(constraints.maxWidth, constraints.hasBoundedHeight ? constraints.maxHeight : constraints.maxWidth);
      LeanPoint? last;
      final painter = CustomPaint(
        size: Size.square(side),
        painter: _CompassPainter(
          position: position,
          trail: trail,
          target: target,
          corners: corners,
          labels: labels && side >= 120,
          border: palette.border,
          muted: palette.muted,
          accent: palette.accent,
          onSurface: onSurface,
          background: palette.surface2,
          quadrants: _quadrantColors,
        ),
      );
      if (onPick == null && onPickEnd == null) {
        return Semantics(
          label: position == null ? 'Compass, no position yet' : 'Compass: ${position!.describe}',
          child: painter,
        );
      }
      void pick(Offset local) {
        last = _toPoint(local, side);
        onPick?.call(last!);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => pick(d.localPosition),
        onTapUp: (_) {
          if (last != null) onPickEnd?.call(last!);
        },
        onPanStart: (d) => pick(d.localPosition),
        onPanUpdate: (d) => pick(d.localPosition),
        onPanEnd: (_) {
          if (last != null) onPickEnd?.call(last!);
        },
        child: Semantics(label: 'Compass. Tap or drag to pick a point.', child: painter),
      );
    });
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.position,
    required this.trail,
    required this.target,
    required this.corners,
    required this.labels,
    required this.border,
    required this.muted,
    required this.accent,
    required this.onSurface,
    required this.background,
    required this.quadrants,
  });

  final LeanPoint? position;
  final List<LeanPoint> trail;
  final LeanPoint? target;
  final List<String?>? corners;
  final bool labels;
  final Color border, muted, accent, onSurface, background;
  final List<Color> quadrants;

  Offset _at(LeanPoint p, Size s) => Offset((p.x + 1) / 2 * s.width, (1 - p.y) / 2 * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width * 0.06);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, r);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = background);

    final half = size.width / 2;
    final quads = [
      Rect.fromLTWH(0, 0, half, half),
      Rect.fromLTWH(half, 0, half, half),
      Rect.fromLTWH(0, half, half, half),
      Rect.fromLTWH(half, half, half, half),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(quads[i], Paint()..color = quadrants[i].withValues(alpha: 0.10));
    }

    // grid
    final grid = Paint()
      ..color = border
      ..strokeWidth = 1;
    for (final f in [0.25, 0.75]) {
      canvas.drawLine(Offset(size.width * f, 0), Offset(size.width * f, size.height),
          grid..color = border.withValues(alpha: 0.45));
      canvas.drawLine(Offset(0, size.height * f), Offset(size.width, size.height * f), grid);
    }
    final axis = Paint()
      ..color = muted.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(half, 0), Offset(half, size.height), axis);
    canvas.drawLine(Offset(0, half), Offset(size.width, half), axis);

    if (labels) {
      final fs = (size.width / 26).clamp(9.0, 12.0);
      void label(String text, Offset at, {Alignment align = Alignment.center}) {
        final tp = TextPainter(
          text: TextSpan(
              text: text,
              style: TextStyle(fontSize: fs, color: muted, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = at.dx - tp.width * (align.x + 1) / 2;
        final dy = at.dy - tp.height * (align.y + 1) / 2;
        tp.paint(canvas, Offset(dx, dy));
      }

      const pad = 6.0;
      label('AUTHORITARIAN', Offset(half, pad), align: Alignment.topCenter);
      label('LIBERTARIAN', Offset(half, size.height - pad), align: Alignment.bottomCenter);
      label('LEFT', Offset(pad, half - 4), align: Alignment.bottomLeft);
      label('RIGHT', Offset(size.width - pad, half - 4), align: Alignment.bottomRight);

      final c = corners;
      if (c != null && c.length == 4) {
        for (var i = 0; i < 4; i++) {
          final text = c[i];
          if (text == null) continue;
          final tp = TextPainter(
            text: TextSpan(
                text: text,
                style: TextStyle(fontSize: fs * 1.5, color: onSurface, fontWeight: FontWeight.w700)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: half - 12);
          tp.paint(canvas, quads[i].center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // trail: older points fainter
    if (trail.length > 1) {
      for (var i = 1; i < trail.length; i++) {
        final t = i / (trail.length - 1);
        canvas.drawLine(
          _at(trail[i - 1], size),
          _at(trail[i], size),
          Paint()
            ..color = accent.withValues(alpha: 0.15 + 0.45 * t)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      for (var i = 0; i < trail.length - 1; i++) {
        canvas.drawCircle(_at(trail[i], size), 2.5,
            Paint()..color = accent.withValues(alpha: 0.25 + 0.4 * i / trail.length));
      }
    }

    final tgt = target;
    if (tgt != null) {
      final c = _at(tgt, size);
      final ring = Paint()
        ..color = onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rad = (size.width / 22).clamp(6.0, 12.0);
      canvas.drawCircle(c, rad, ring);
      canvas.drawLine(c - Offset(rad + 4, 0), c - Offset(rad - 3, 0), ring);
      canvas.drawLine(c + Offset(rad - 3, 0), c + Offset(rad + 4, 0), ring);
      canvas.drawLine(c - Offset(0, rad + 4), c - Offset(0, rad - 3), ring);
      canvas.drawLine(c + Offset(0, rad - 3), c + Offset(0, rad + 4), ring);
    }

    final pos = position;
    if (pos != null) {
      final c = _at(pos, size);
      final rad = (size.width / 30).clamp(3.5, 8.0);
      canvas.drawCircle(c, rad + 6, Paint()..color = accent.withValues(alpha: 0.18));
      canvas.drawCircle(c, rad + 1.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, rad, Paint()..color = accent);
    }
    canvas.restore();

    canvas.drawRRect(
        rrect,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.position != position ||
      old.trail != trail ||
      old.target != target ||
      old.corners != corners ||
      old.labels != labels ||
      old.accent != accent ||
      old.background != background;
}

/// A tiny compass for buttons: the frame, the axes and the user's dot.
class MiniCompass extends StatelessWidget {
  const MiniCompass({this.position, this.active = false, this.size = 24, super.key});

  final LeanPoint? position;

  /// The feed filter is on (drawn with a stronger frame).
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: _MiniPainter(
        position: position,
        frame: active ? palette.accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        axis: palette.muted,
        dot: palette.accent,
      ),
    );
  }
}

class _MiniPainter extends CustomPainter {
  _MiniPainter({required this.position, required this.frame, required this.axis, required this.dot});

  final LeanPoint? position;
  final Color frame, axis, dot;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.22)),
        Paint()
          ..color = frame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    final p = Paint()
      ..color = axis
      ..strokeWidth = 1;
    canvas.drawLine(Offset(rect.center.dx, rect.top + 3), Offset(rect.center.dx, rect.bottom - 3), p);
    canvas.drawLine(Offset(rect.left + 3, rect.center.dy), Offset(rect.right - 3, rect.center.dy), p);
    final pos = position;
    if (pos != null) {
      final c = Offset(rect.left + (pos.x + 1) / 2 * rect.width, rect.top + (1 - pos.y) / 2 * rect.height);
      canvas.drawCircle(c, size.width * 0.13, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) => old.position != position || old.frame != frame || old.dot != dot;
}
