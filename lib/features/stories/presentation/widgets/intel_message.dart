import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Calm centred message for empty and error states, with an optional action.
class IntelMessage extends StatelessWidget {
  const IntelMessage({
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.onAction,
    this.outlined = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  /// Outlined for "Try again"; filled red for "Show all …".
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = action == null
        ? null
        : outlined
            ? OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 44),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: Text(action!),
              )
            : FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(150, 44),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: Text(action!),
              );

    // A scrollable so pull-to-refresh still works on empty and error states.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: palette.muted),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, height: 1.45, color: palette.muted)),
                  if (button != null) ...[
                    const SizedBox(height: 22),
                    button,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
