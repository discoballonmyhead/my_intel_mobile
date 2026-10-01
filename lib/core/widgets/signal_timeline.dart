import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Building blocks of the "Signal" timeline: a dashed line down a left
/// gutter, each entry's clock time and pin on it, sticky per-day date chips
/// and a LIVE ticker of recent regions.

/// Width of the timeline gutter; the line runs down its centre.
const double kSignalGutter = 58;

/// Dashed vertical line down the middle of the gutter. Each row and each day
/// header paints its own segment, so the line looks continuous.
class SignalSpinePainter extends CustomPainter {
  const SignalSpinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const x = kSignalGutter / 2;
    for (var y = 0.0; y < size.height; y += 10) {
      canvas.drawLine(
          Offset(x, y), Offset(x, (y + 6).clamp(0, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(SignalSpinePainter old) => old.color != color;
}

/// One timeline row: [time] above a pin above an "ago" label in the gutter,
/// then [child] (the card).
class SignalRow extends StatelessWidget {
  const SignalRow({
    required this.time,
    required this.pin,
    required this.child,
    super.key,
  });

  final DateTime time;
  final SignalPin pin;
  final Widget child;

  static String ago(DateTime t) {
    final d = DateTime.now().toUtc().difference(t.toUtc());
    if (d.inMinutes < 1) return 'NOW';
    if (d.inMinutes < 60) return '${d.inMinutes}M';
    if (d.inHours < 24) return '${d.inHours}H';
    return '${d.inDays}D';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final local = time.toLocal();
    return CustomPaint(
      painter: SignalSpinePainter(color: palette.border),
      child: Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kSignalGutter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(DateFormat.Hm().format(local),
                          style: AppTypography.mono(
                              size: 10,
                              weight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface)),
                    ),
                    const SizedBox(height: 5),
                    pin,
                    const SizedBox(height: 5),
                    Text(ago(time),
                        style: AppTypography.mono(
                            size: 8,
                            weight: FontWeight.w600,
                            color: palette.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

enum SignalPinKind { hollow, filled, dimmed }

/// Pin on the timeline. Filled (optionally pulsing), dimmed or hollow.
class SignalPin extends StatefulWidget {
  const SignalPin({required this.kind, this.pulse = false, this.color, super.key});

  final SignalPinKind kind;
  final bool pulse;

  /// Defaults to the theme accent.
  final Color? color;

  @override
  State<SignalPin> createState() => _SignalPinState();
}

class _SignalPinState extends State<SignalPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ping =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SignalPin old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.pulse && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ping.isAnimating) {
      _ping.repeat();
    } else if (!animate && _ping.isAnimating) {
      _ping.stop();
    }
  }

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final color = widget.color ?? palette.accent;

    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (widget.kind) {
          SignalPinKind.filled => color,
          SignalPinKind.dimmed => color.withValues(alpha: 0.55),
          SignalPinKind.hollow => bg,
        },
        border: widget.kind == SignalPinKind.hollow
            ? Border.all(color: palette.muted, width: 2)
            : null,
        boxShadow: [BoxShadow(color: bg, spreadRadius: 3)],
      ),
    );
    if (!widget.pulse) return dot;

    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _ping,
            builder: (context, _) => Transform.scale(
              scale: 0.6 + 2.0 * _ping.value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.9 * (1 - _ping.value)),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          dot,
        ],
      ),
    );
  }
}

/// Items for one local calendar day.
class SignalDay<T> {
  SignalDay(this.date) : items = [];

  final DateTime date;
  final List<T> items;

  /// TODAY · 30 SEP, YESTERDAY · 29 SEP, MON · 28 SEP (year added when it
  /// differs from this year).
  String get label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    final dayMonth = DateFormat('d MMM').format(date).toUpperCase();
    final withYear = date.year == now.year ? dayMonth : '$dayMonth ${date.year}';
    return switch (diff) {
      0 => 'TODAY · $withYear',
      1 => 'YESTERDAY · $withYear',
      _ => '${DateFormat('EEE').format(date).toUpperCase()} · $withYear',
    };
  }

  /// Groups [items] (already newest first) by the local day of [timeOf].
  static List<SignalDay<T>> group<T>(
      Iterable<T> items, DateTime Function(T) timeOf) {
    final days = <SignalDay<T>>[];
    for (final item in items) {
      final t = timeOf(item).toLocal();
      final d = DateTime(t.year, t.month, t.day);
      if (days.isEmpty || days.last.date != d) days.add(SignalDay<T>(d));
      days.last.items.add(item);
    }
    return days;
  }
}

/// Date chip on the timeline that stays pinned while its day is on screen;
/// the next day's chip pushes it away (use inside a SliverMainAxisGroup).
class SignalDayHeader extends SliverPersistentHeaderDelegate {
  const SignalDayHeader(this.label);

  final String label;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    return CustomPaint(
      painter: SignalSpinePainter(color: context.palette.border),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Semantics(
            header: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: onSurface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 11, color: surface),
                  const SizedBox(width: 6),
                  Text(label,
                      style: AppTypography.mono(
                          size: 9,
                          weight: FontWeight.w700,
                          color: surface,
                          letterSpacing: 1.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(SignalDayHeader old) => old.label != label;
}

/// "LIVE" strip scrolling through recent regions, e.g. ("KHARKIV", "5H").
class LiveTicker extends StatefulWidget {
  const LiveTicker({required this.entries, super.key});

  final List<(String, String)> entries;

  @override
  State<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends State<LiveTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(vsync: this);

  static const _dotColors = [
    AppColors.regionBreaking,
    AppColors.regionBusy,
    AppColors.regionQuiet,
  ];
  static const double _gap = 22;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(LiveTicker old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.entries, widget.entries)) _restart();
  }

  void _restart() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.stop();
      return;
    }
    // About 25 logical px per second however many regions there are.
    final seconds = (_runWidth / 25).clamp(6, 60);
    _scroll
      ..duration = Duration(milliseconds: (seconds * 1000).round())
      ..repeat();
  }

  TextStyle get _style => AppTypography.mono(
      size: 10, weight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2);

  double get _runWidth {
    var w = 0.0;
    for (final (region, ago) in widget.entries) {
      final tp = TextPainter(
        text: TextSpan(text: '● $region · $ago', style: _style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      w += tp.width + _gap;
    }
    return w;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = Theme.of(context).brightness == Brightness.dark
        ? palette.surface2
        : const Color(0xFF1A1614);

    Widget run() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '● ',
                        style: TextStyle(color: _dotColors[i % _dotColors.length])),
                    TextSpan(
                        text: '${widget.entries[i].$1} · ${widget.entries[i].$2}'),
                  ]),
                  style: _style,
                ),
              ),
          ],
        );

    final width = _runWidth;
    return Semantics(
      label: 'Live: ${widget.entries.map((e) => e.$1).join(', ')}',
      child: Container(
        height: 30,
        color: ink,
        child: Row(
          children: [
            Container(
              color: palette.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Text('● LIVE',
                  style: AppTypography.mono(
                      size: 9,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5)),
            ),
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(14 - _scroll.value * width, 0),
                    child: child,
                  ),
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [run(), run(), run()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
