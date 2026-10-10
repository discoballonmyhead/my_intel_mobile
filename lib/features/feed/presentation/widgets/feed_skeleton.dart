import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shimmering placeholder posts shown while the feed loads, shaped like real
/// cards so the page doesn't jump when content arrives.
class FeedSkeleton extends StatefulWidget {
  const FeedSkeleton({super.key});

  @override
  State<FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = palette.surface2;
    final light = Color.lerp(base, Theme.of(context).colorScheme.surface, 0.6)!;

    return Semantics(
      label: 'Loading feed',
      child: AnimatedBuilder(
        animation: _shine,
        builder: (context, _) {
          final t = _shine.value;
          final shader = LinearGradient(
            colors: [base, light, base],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(-3 + 4 * t, 0),
            end: Alignment(-1 + 4 * t, 0),
          );
          Widget block(double? w, double h, double r) => Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  gradient: shader,
                  borderRadius: BorderRadius.circular(r),
                ),
              );

          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, i) => Container(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 16, AppSpacing.lg, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(36, 36, 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(110.0 + i * 14, 12, 6),
                        const SizedBox(height: 10),
                        block(double.infinity, 11, 6),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: i.isEven ? 0.6 : 0.8,
                          child: block(null, 11, 6),
                        ),
                        if (i == 1) ...[
                          const SizedBox(height: 10),
                          block(double.infinity, 150, 14),
                        ],
                        const SizedBox(height: 10),
                        block(120, 9, 5),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            block(34, 14, 7),
                            const SizedBox(width: 26),
                            block(34, 14, 7),
                            const SizedBox(width: 26),
                            block(34, 14, 7),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
