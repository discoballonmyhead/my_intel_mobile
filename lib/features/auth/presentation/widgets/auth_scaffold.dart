import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shared chrome for the auth screens: a dotted paper background, an animated
/// [stage] that takes whatever height the [form] leaves free, and the form
/// pinned to the bottom. When the keyboard opens or the form grows, the stage
/// shrinks first and the whole column scrolls once there is no room left.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.stage,
    required this.form,
    this.topBar,
    super.key,
  });

  final Widget stage;
  final Widget form;
  final Widget? topBar;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surface2,
      body: CustomPaint(
        painter: _DotGridPainter(Theme.of(context).colorScheme.onSurface),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (topBar != null) topBar!,
                          Expanded(child: _StageSlot(child: stage)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                22, AppSpacing.sm, 22, AppSpacing.xl),
                            child: form,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports a small fixed intrinsic height for the stage, so IntrinsicHeight
/// sizes the column by the form and the stage only gets the space left over
/// (instead of forcing a scroll to fit its full radar).
class _StageSlot extends SingleChildRenderObjectWidget {
  const _StageSlot({required super.child});

  static const double minHeight = 180;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStageSlot();
}

class _RenderStageSlot extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => _StageSlot.minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _StageSlot.minHeight;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink.withValues(alpha: 0.08);
    const step = 18.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.ink != ink;
}

/// Inline error banner used by the auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accent2.withValues(alpha: 0.08),
        border: Border.all(color: palette.accent2.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: palette.accent2),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: palette.accent2),
            ),
          ),
        ],
      ),
    );
  }
}
